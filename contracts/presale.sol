// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Presale is Ownable {
    using SafeMath for uint256;
    
    IERC20 public token;
    address payable public presale;
    uint256 public presaleStartTimestamp;
    uint256 public presaleEndTimestamp;
    uint256 public softCapEthAmount = 50 ether;
    uint256 public hardCapEthAmount = 150 ether;
    uint256 public totalDepositedEthBalance;
    uint256 public minimumDepositEthAmount = 0 ether;
    uint256 public maximumDepositEthAmount = 3 ether;
    
    uint256 rewardTokenCount = 0.0125 ether; // 80 tokens per BNB
    
    bool public startUnlocked;
    bool public endUnlocked;
    bool public claimUnlocked;
    bool public newTokenUpdate;
    
    mapping(address => uint256) public deposits;
    
    constructor(
        uint256 startTimestamp,
        uint256 endTimestamp
    ) {
        presale =  payable(0xc52B651d2005A7eB4DF03e9A0666A957A4B17f76);
        
        presaleStartTimestamp = startTimestamp;
        presaleEndTimestamp = endTimestamp;
        
        newTokenUpdate = false;
    }
    
    event StartUnlockedEvent(uint256 startTimestamp);
    event EndUnlockedEvent(uint256 endTimestamp);
    
    receive() payable external {
        deposit();
    }
    
    function deposit() public payable {
        require(startUnlocked, "presale has not yet started");
        require(!endUnlocked, "presale already ended");
        // require(block.timestamp >= presaleStartTimestamp && block.timestamp <= presaleEndTimestamp, "presale is not active");
        require(totalDepositedEthBalance.add(msg.value) <= hardCapEthAmount, "deposit limits reached");
        require(deposits[msg.sender].add(msg.value) >= minimumDepositEthAmount && deposits[msg.sender].add(msg.value) <= maximumDepositEthAmount, "incorrect amount");
        
        totalDepositedEthBalance = totalDepositedEthBalance.add(msg.value);
        deposits[msg.sender] = deposits[msg.sender].add(msg.value);
        emit Deposited(msg.sender, msg.value);
    }
    
    function releaseFunds() external onlyOwner {
        require(endUnlocked);
        // require(block.timestamp >= presaleEndTimestamp || totalDepositedEthBalance == hardCapEthAmount, "presale is active");
        presale.transfer(address(this).balance);
    }
    
    function withdrawToken() external onlyOwner {
        require(endUnlocked);
        require(newTokenUpdate, "new token is not updated");
        // require(block.timestamp >= presaleEndTimestamp || totalDepositedEthBalance == hardCapEthAmount, "presale is active");
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
    
    function claimToken() public {
        require(endUnlocked, "too early to claim");
        require(newTokenUpdate, "new token is not updated");
        uint256 tokenAmount = deposits[msg.sender].mul(1e18).div(rewardTokenCount);
        token.transfer(msg.sender, tokenAmount);
    }
    
    function recoverToken(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).transfer(this.owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }
    
    function getDepositAmount() public view returns (uint256) {
        return totalDepositedEthBalance;
    }
    
    function getLeftTimeAmount() public view returns (uint256) {
        if(block.timestamp > presaleEndTimestamp) {
            return 0;
        } else {
            return (presaleEndTimestamp - block.timestamp);
        }
    }
    
    function unlockStart() external onlyOwner {
        require(!startUnlocked, 'Presale already started!');
        startUnlocked = true;
        emit StartUnlockedEvent(block.timestamp);
    }
    function unlockEnd() external onlyOwner {
        require(!endUnlocked, 'Presale already ended!');
        endUnlocked = true;
        emit EndUnlockedEvent(block.timestamp);
    }
    
    function setToken(address _token) public onlyOwner {
        token = IERC20(_token);
    }
    
    function setNewTokenUpdate(bool _update) public onlyOwner {
        newTokenUpdate = _update;
    }
    
    event Deposited(address indexed user, uint256 amount);
    event Recovered(address token, uint256 amount);
}