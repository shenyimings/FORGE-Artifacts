// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IRedeemChecker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

contract RedeemChecker is IRedeemChecker, Ownable {
    address public badgeAddress;
    uint256 public minAmt;

    constructor(address _badgeAddress, uint256 _minAmt) {
        badgeAddress = _badgeAddress;
        setMinAmt(_minAmt);
    }

    /**
     * Check if `_recipient` is qualified to redeem
     * @param _recipient The address to check
     */
    function qualified(address _recipient)
        external
        view
        override
        returns (bool)
    {
        return IERC721(badgeAddress).balanceOf(_recipient) >= minAmt;
    }

    /********** Admin-only functions **********/
    function setMinAmt(uint256 _minAmt) public onlyOwner {
        require(_minAmt > 0, "RedeemChecker: minAmt must be greater than 0");
        minAmt = _minAmt;
    }
}
