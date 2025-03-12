pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import {ILendingPool} from './interfaces/ILendingPool.sol';
import {IWETH} from './interfaces/IWETH.sol';
import {IAToken} from './interfaces/IAToken.sol';

contract WETHGateway {
    IWETH internal immutable WETH;
    IAToken internal immutable aWETH;

    constructor(address weth, address aWETH_) public {
        WETH = IWETH(weth);
        aWETH = IAToken(aWETH_);
    }

    function authorizeLendingPool(address lendingPool) external {
        WETH.approve(lendingPool, uint256(-1));
    }

    function depositETH(
        address lendingPool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable {
        WETH.deposit{value: msg.value}();
        ILendingPool(lendingPool).deposit(address(WETH), msg.value, onBehalfOf, referralCode);
    }

    function withdrawETH(
        address lendingPool,
        uint256 amount,
        address to
    ) external {
        uint256 amountToWithdraw = amount;
        aWETH.transferFrom(msg.sender, address(this), amountToWithdraw);
        ILendingPool(lendingPool).withdraw(address(WETH), amountToWithdraw, address(this));
        WETH.withdraw(amountToWithdraw);
        _safeTransferETH(to, amountToWithdraw);
    }

    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'ETH_TRANSFER_FAILED');
    }

    function getWETHAddress() external view returns (address) {
        return address(WETH);
    }

    /**
     * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
     */
    receive() external payable {
        require(msg.sender == address(WETH), 'Receive not allowed');
    }

    /**
     * @dev Revert fallback calls
     */
    fallback() external payable {
        revert('Fallback not allowed');
    }
}
