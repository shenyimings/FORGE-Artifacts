pragma solidity 0.5.16;

import { AbsBToken } from "./AbsBToken.sol";
import { IAvatarCErc20 } from "../interfaces/IAvatar.sol";
import { ICToken } from "../interfaces/CTokenInterfaces.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BErc20 is AbsBToken {

    IERC20 public underlying;

    constructor(
        address _registry,
        address _cToken
    ) public AbsBToken(_registry, _cToken) {
        underlying = ICToken(cToken).underlying();
    }

    // mint()
    function mint(uint256 mintAmount) external returns (uint256) {
        return _mint(_myAvatar(), mintAmount);
    }

    function mintOnAvatar(address _avatar, uint256 mintAmount) external onlyDelegatee(_avatar) returns (uint256) {
        return _mint(_avatar, mintAmount);
    }

    function _mint(address _avatar, uint256 mintAmount) internal returns (uint256) {
        underlying.safeTransferFrom(msg.sender, _avatar, mintAmount);
        uint256 result = IAvatarCErc20(_avatar).mint(cToken, mintAmount);
        require(result == 0, "BErc20: mint-failed");
        return result;
    }

    // repayBorrow()
    function repayBorrow(uint256 repayAmount) external returns (uint256) {
        return _repayBorrow(_myAvatar(), repayAmount);
    }

    function repayBorrowOnAvatar(address _avatar, uint256 repayAmount) external onlyDelegatee(_avatar) returns (uint256) {
        return _repayBorrow(_avatar, repayAmount);
    }

    function _repayBorrow(address _avatar, uint256 repayAmount) internal returns (uint256) {
        uint256 actualRepayAmount = repayAmount;
        if(repayAmount == uint256(-1)) {
            actualRepayAmount = IAvatarCErc20(_avatar).borrowBalanceCurrent(cToken);
        }
        underlying.safeTransferFrom(msg.sender, _avatar, actualRepayAmount);
        uint256 result = IAvatarCErc20(_avatar).repayBorrow(cToken, actualRepayAmount);
        require(result == 0, "BErc20: repayBorrow-failed");
        return result;
    }
}