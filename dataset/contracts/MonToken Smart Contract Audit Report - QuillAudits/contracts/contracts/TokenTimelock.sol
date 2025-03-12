// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenTimelock is Ownable{

    // ERC20 basic token contract being held
    IERC20 private _token;

    // beneficiary of tokens to lock info
    mapping(address => uint256) internal _beneficiaryLocks;

    // beneficiary to release time
    mapping(address => uint256) internal _releaseTimes;

    constructor (address tokenAddress) {
        _token = IERC20(tokenAddress);
    }

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20) {
        return _token;
    }

    /**
     * @return the amount of token lock.
     */
    function lockAmount(address _beneficiaryAddress) public view virtual returns (uint256) {
        return _beneficiaryLocks[_beneficiaryAddress];
    }

    /**
     * @return the time when the tokens are released.
     */
    function releaseTime(address _beneficiaryAddress) public view virtual returns (uint256) {
        return _releaseTimes[_beneficiaryAddress];
    }

    /**
     * @notice Set new address for token.
     */
    function setToken(address newAddress) public onlyOwner{
        require(newAddress != address(0), "Zero address");
        _token = IERC20(newAddress);
    }

    /**
     * @notice Set new beneficiary lock.
     */
    function setLock(address beneficiaryAddress, uint amount, uint timeRelease) public onlyOwner{
        require(beneficiaryAddress != address(0), "Zero address");
        require(timeRelease > block.timestamp, "Release time is before current time");
        uint256 amountCurrent = _beneficiaryLocks[beneficiaryAddress];
        require(amountCurrent == 0, "Exist beneficiary token time lock");

        require(_token.transferFrom(_msgSender(), address(this), amount));
        _beneficiaryLocks[beneficiaryAddress] = amount;
        _releaseTimes[beneficiaryAddress] = timeRelease;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public virtual {
        uint256 timeRelease = _releaseTimes[_msgSender()];
        require(block.timestamp >= timeRelease, "Current time is before release time");
        uint256 amount = _beneficiaryLocks[_msgSender()];
        if (amount > 0) {
            require(token().transfer(_msgSender(), amount));
        }
        _beneficiaryLocks[_msgSender()] = 0;
    }
}