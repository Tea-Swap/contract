// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract MINT is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    address private _communicationAddress = 0x6eC37f8Fb02A69A12BDEF5632CDcF66e25BCc6f3; // address marketing
    address private _teamAddress = 0xd38D2C9Af3D610735099832d1A5cc30369F36479; // address team

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1;  // MAX SUPPLY 280 000
    uint256 private _maxSupply = 280000 ether;
    uint256 private _rTotal = (MAX.div(280000 ether) - (MAX.div(280000 ether) % _tTotal));
    uint256 private _tFeeTotal;
    
    string public constant name = "TeaSwap";
    string public constant symbol = "MINT";
    uint8 public constant decimals = 18;
    
    uint256 public _dFee = 19;
    uint256 public _previousDFee = _dFee;
    uint256 public _cFee = 17;
		uint256 public _previousCFee = _cFee;
		uint256 public _tFee = 20;
		uint256 public _previousTFee = _tFee;
		uint256 public _bFee = 20;
		uint256 public _previousBFee = _bFee;
		
		mapping(address => bool) public excludedFeeAccounts; // if recipient account exist in this array remove fee
	
	
	// address public liquidityMiningAddress = 0x70F29e30c90000000352caf2205a687eC1e1A238;
    // address private marketingAddress = 0x70F29e30c90000000352caf2205a687eC1e1A238;
    // address private devLeadAddress = 0x70F29e30c90000000352caf2205a687eC1e1A238;

    constructor () {

        // liquidityMiningAddress = _liquidityMiningAddress;
        // marketingAddress = _marketingAddress;
        // devLeadAddress = _devLeadAddress;

        _rOwned[_msgSender()] = _rTotal;
        emit Transfer(address(0), _msgSender(), _tTotal);

        // transfer(liquidityMiningAddress, 9000 ether);
        // transfer(marketingAddress, 3000 ether);
        // transfer(devLeadAddress, 6000 ether);

    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
	     // if(excludedFeeAccounts[recipient] == true) removeFee();
	       if(excludedFeeAccounts[_msgSender()] == true) removeFee();
	    
        _transfer(_msgSender(), recipient, amount);
	    
	      restoreFee();
      
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeAccount(address account) external onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeAccount(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (, uint256 tFee, uint256 dFee, uint256 cFee, uint256 burningAmount) = _getValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount,,,) = _getRValues(tAmount, tFee, dFee, cFee, burningAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _absorbTransfer(sender, recipient, tAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 dFee, uint256 cFee, uint256 burningAmount) = _getValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount,,,) = _getRValues(tAmount, tFee, dFee, cFee, burningAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _absorbTransfer(sender, recipient, tAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (, uint256 tFee, uint256 dFee, uint256 cFee, uint256 burningAmount) = _getValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount,,,) = _getRValues(tAmount, tFee, dFee, cFee, burningAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _absorbTransfer(sender, recipient, tAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 dFee, uint256 cFee, uint256 burningAmount) = _getValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount,,,) = _getRValues(tAmount, tFee, dFee, cFee, burningAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _absorbTransfer(sender, recipient, tAmount);
    }

    function _absorbTransfer(address sender, address recipient, uint256 tAmount) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 dFee, uint256 cFee, uint256 burningAmount) = _getValues(tAmount);
        (,, uint256 rFee, uint256 rdFee, uint256 rcFee) = _getRValues(tAmount, tFee, dFee, cFee, burningAmount);
        _absorbFee(rFee, tFee);
        _devFee(sender, dFee, rdFee);
        _communicationFee(sender, cFee, rcFee);
        _burn(sender, burningAmount);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _absorbFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _devFee(address sender, uint256 dFee, uint256 rdFee) private {
	    if(dFee > 0) {
        if (_isExcluded[_teamAddress]) {
            _tOwned[_teamAddress] = _tOwned[_teamAddress].add(dFee);
            _rOwned[_teamAddress] = _rOwned[_teamAddress].add(rdFee);
        } else {
            _rOwned[_teamAddress] = _rOwned[_teamAddress].add(rdFee);
        }
        emit Transfer(sender, _teamAddress, dFee);
	    }
    }

    function _communicationFee(address sender, uint256 cFee, uint256 rcFee) private {
	    if(cFee > 0) {
        if (_isExcluded[_communicationAddress]) {
            _tOwned[_communicationAddress] = _tOwned[_communicationAddress].add(cFee);
            _rOwned[_communicationAddress] = _rOwned[_communicationAddress].add(rcFee);
        } else {
            _rOwned[_communicationAddress] = _rOwned[_communicationAddress].add(rcFee);
        }
        emit Transfer(sender, _communicationAddress, cFee);
	    }
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tFee, uint256 dFee, uint256 cFee, uint256 burningAmount, uint256 tTransferAmount) = _getTDBValues(tAmount);
        return (tTransferAmount, tFee, dFee, cFee, burningAmount);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 dFee, uint256 cFee, uint256 burningAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        uint256 currentRate =  _getRate();
        (uint256 rAmount) = _getRAmountValues(tAmount, currentRate);
        (uint256 rFee) = _getRFeeValues(tFee, currentRate);
        (uint256 rdFee) = _getRDFeeValues(dFee, currentRate);
        (uint256 rcFee) = _getRcFeeValues(cFee, currentRate);
        (uint256 rBurningAmount) = _getRBurningAmountValue(burningAmount, currentRate);
        (uint256 rTransferAmount) = _getRTransfertAmountValue(rAmount, rFee, rdFee, rcFee, rBurningAmount);
        return (rAmount, rTransferAmount, rFee, rdFee, rcFee);
    }

    function _getTDBValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tFee, uint256 dFee, uint256 cFee) = _getTDValues(tAmount);
        (uint256 burningAmount) = _getBurningValues(tAmount);
        (uint256 tTransferAmount) = _getTransfertAmountValues(tAmount, tFee, dFee, cFee, burningAmount);
        return (tFee, dFee, cFee, burningAmount, tTransferAmount);
    }

    function _getTDValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = tAmount.mul(_tFee).div(1000); // splash distribution fee 2.0%
        uint256 dFee = tAmount.mul(_dFee).div(1000); // send 1.9% to team wallet
        uint256 cFee = tAmount.mul(_cFee).div(1000); // send 1.7% to communication wallet
        return (tFee, dFee, cFee);
    }

    function _getBurningValues(uint256 tAmount) private view returns (uint256) {
        uint256 burningAmount = (tAmount.div(10000)).mul(_bFee); // burn 0.2%
        return (burningAmount);
    }

    function _getRAmountValues(uint256 tAmount, uint256 currentRate) private pure returns (uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        return (rAmount);
    }

    function _getRFeeValues(uint256 tFee, uint256 currentRate) private pure returns (uint256) {
        uint256 rFee = tFee.mul(currentRate);
        return (rFee);
    }

    function _getRDFeeValues(uint256 dFee, uint256 currentRate) private pure returns (uint256) {
        uint256 rdFee = dFee.mul(currentRate);
        return (rdFee);
    }

    function _getRcFeeValues(uint256 cFee, uint256 currentRate) private pure returns (uint256) {
        uint256 rcFee = cFee.mul(currentRate);
        return (rcFee);
    }

    function _getRBurningAmountValue(uint256 burningAmount, uint256 currentRate) private pure returns (uint256) {
        uint256 rBurningAmount = burningAmount.mul(currentRate);
        return (rBurningAmount);
    }

    function _getTransfertAmountValues(uint256 tAmount, uint256 tFee, uint256 dFee, uint256 cFee, uint256 burningAmount) private pure returns (uint256) {
        uint256 tTransferAmount = ((((tAmount.sub(tFee)).sub(dFee)).sub(cFee)).sub(burningAmount));
        return (tTransferAmount);
    }

    function _getRTransfertAmountValue(uint256 rAmount, uint256 rFee, uint256 rdFee, uint256 rcFee, uint256 rBurningAmount) private pure returns (uint256) {
        uint256 rTransferAmount = ((((rAmount.sub(rFee)).sub(rdFee)).sub(rcFee)).sub(rBurningAmount));
        return (rTransferAmount);
    }

    function _burn(address account, uint256 burningAmount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 currentRate =  _getRate();
        uint256 rBurningAmount = burningAmount.mul(currentRate);
        _tTotal = _tTotal.sub(burningAmount);
        _rTotal = _rTotal.sub(rBurningAmount);
	      if(burningAmount > 0)
        emit Transfer(account, address(0), burningAmount);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function removeFee() internal {
	    _dFee = 0;
	    _cFee = 0;
	    _tFee = 0;
	    _bFee = 0;
    }
    
    function restoreFee() internal {
	    _dFee = _previousDFee;
	    _cFee = _previousCFee;
	    _tFee = _previousTFee;
	    _bFee = _previousBFee;
    }
	
		function excludeFromFee(address account, bool exclude) public onlyOwner {
			excludedFeeAccounts[account] = exclude;
		}
    
    function addSupply(uint256 tAmount) internal {
        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount.mul(currentRate);
        _rTotal = _rTotal.add(rAmount);
        _tTotal = _tTotal.add(tAmount);
        _rOwned[_msgSender()] = _rOwned[_msgSender()].add(rAmount);
    }
    
    function mint(uint256 tAMount) public onlyOwner {
        require(tAMount + _tTotal <= _maxSupply, "cap exceeded!");
        addSupply(tAMount);
        emit Transfer(address(0), _msgSender(), tAMount);
    }
}
