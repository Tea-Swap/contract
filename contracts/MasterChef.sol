// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./MINT.sol";

// MasterChef is the master of mint. He can make mint and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once mint is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChefV2 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of mints
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accmintPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accmintPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. mint to distribute per block.
        uint256 lastRewardBlock;  // Last block number that mint distribution occurs.
        uint256 accmintPerShare;   // Accumulated mint per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
        uint256 endBlock;
        uint256 startBlock;
    }
    
    // The mint TOKEN!
    MINT public Mint;
    // Dev address.
    address public devaddr;
    // mint tokens created per block.
    uint256 public mintPerBlock;
    // Bonus muliplier for early mint makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Deposit Fee address
    address public feeAddBb;
    address public feeAddSt;
    
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when mint mining starts.
    uint256 public startBlock;
    
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddressBb(address indexed user, address indexed newAddress);
    event SetFeeAddressSt(address indexed user, address indexed newAddress);
    event SetDevAddress(address indexed user, address indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 mintPerBlock);
    
    constructor(
        MINT _mint,
        address _devaddr,
        uint256 _mintPerBlock,
        uint256 _startBlock,
        address _feeAddBb,
        address _feeAddSt
    ) {
        Mint = _mint;
        devaddr = _devaddr;
        mintPerBlock = _mintPerBlock;
        startBlock = _startBlock;
        feeAddBb = _feeAddBb;
        feeAddSt = _feeAddSt;
    }
    
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    
    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }
    
    modifier poolExists(uint256 pid) {
        require(pid < poolInfo.length, "pool inexistent");
        _;
    }
    
    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP, uint256 _endBlock, uint256 _startBlock,  bool _withUpdate) public onlyOwner nonDuplicated(_lpToken) {
        require(_depositFeeBP <= 400, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(PoolInfo({
        lpToken : _lpToken,
        allocPoint : _allocPoint,
        lastRewardBlock : lastRewardBlock,
        accmintPerShare : 0,
        depositFeeBP : _depositFeeBP,
        endBlock : _endBlock,
        startBlock : _startBlock
        }));
    }
    
    // Update the given pool's mint allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner poolExists(_pid) {
        require(_depositFeeBP <= 400, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }
    
    function getMultiplier(uint256 _from, uint256 _to, uint256 bonusEndBlock) internal pure returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from);
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock.sub(_from);
        }
    }
    
    // View function to see pending mints on frontend.
    function pendingmint(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accmintPerShare = pool.accmintPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number, pool.endBlock);
            uint256 mintReward = multiplier.mul(mintPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accmintPerShare = accmintPerShare.add(mintReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accmintPerShare).div(1e12).sub(user.rewardDebt);
    }
    
    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }
    
    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number, pool.endBlock);
        uint256 mintReward = multiplier.mul(mintPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        Mint.mint(mintReward);
        pool.accmintPerShare = pool.accmintPerShare.add(mintReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }
    
    // Deposit LP tokens to MasterChef for mint allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant  poolExists(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
    
        require(block.number > pool.startBlock, "too early");
    
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accmintPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                safemintTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                uint256 depositeFeeHalf = depositFee.div(2);
                pool.lpToken.safeTransfer(feeAddBb, depositeFeeHalf);
                pool.lpToken.safeTransfer(feeAddSt, depositeFeeHalf);
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accmintPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }
    
    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant poolExists(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accmintPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            safemintTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accmintPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }
    
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant poolExists(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }
    
    // Safe mint transfer function, just in case if rounding error causes pool to not have enough mints.
    function safemintTransfer(address _to, uint256 _amount) internal {
        uint256 mintBal = Mint.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > mintBal) {
            transferSuccess = Mint.transfer(_to, mintBal);
        } else {
            transferSuccess = Mint.transfer(_to, _amount);
        }
        require(transferSuccess, "safemintTransfer: transfer failed");
    }
    
    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
        emit SetDevAddress(msg.sender, _devaddr);
    }
    
    function setFeeAddressBb(address _feeAddress) public {
        require(msg.sender == feeAddBb, "setFeeAddress: FORBIDDEN");
        feeAddBb = _feeAddress;
        emit SetFeeAddressBb(msg.sender, _feeAddress);
    }
    
    function setFeeAddressSt(address _feeAddress) public {
        require(msg.sender == feeAddSt, "setFeeAddress: FORBIDDEN");
        feeAddSt = _feeAddress;
        emit SetFeeAddressSt(msg.sender, _feeAddress);
    }
    
}