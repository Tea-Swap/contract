pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract ERC20_TimeLock is ReentrancyGuard, Ownable {
	
	using SafeMath for uint256;
	using Address for address;
	using SafeERC20 for IERC20;
	
	uint public constant GRACE_PERIOD = 14 days;
	uint public constant MINIMUM_DELAY = 1 minutes;
	uint public constant MAXIMUM_DELAY = 30 days;
	
	struct UserInfo {
		uint256 pendingAmount; //set this amount to 0 if user withdraws
		uint256 releaseTime;
	}
	
	mapping(address => mapping(address => UserInfo)) userInfo; // userInfo[userAddress][tokenAddress]
	mapping(address => uint256) tokensLastBalances;
	
	function lock(address _token, address recipient, uint256 _amount, uint256 _releaseTime) public onlyOwner {
		
		require(_releaseTime > block.number, "time has passed"); // should be in future
		
		uint256 tokenLastBalance = tokensLastBalances[_token];
		
		IERC20 token = IERC20(_token);
		uint256 balance = token.balanceOf(address(this));
		require(balance >= tokenLastBalance.add(_amount), "not enough balance");
		
		
		UserInfo storage user = userInfo[recipient][_token];
		user.pendingAmount = _amount;
		user.releaseTime = _releaseTime;
		
		tokensLastBalances[_token] = tokenLastBalance.add(_amount);
	}
	
	// can be called by anyone
	function withDraw(address _token) public nonReentrant {
		UserInfo storage user = userInfo[_msgSender()][_token];
		
		require(user.releaseTime <= block.number, "TimeLock::withdraw: too early");
		
		uint256 contractBalance = IERC20(_token).balanceOf(address(this));
		
		require(contractBalance >= user.pendingAmount, "bug");
		
		
		require(user.pendingAmount > 0, "can't withdraw");
		IERC20(_token).transfer(_msgSender(), user.pendingAmount);
			
		user.pendingAmount = 0;

		
	}
}
