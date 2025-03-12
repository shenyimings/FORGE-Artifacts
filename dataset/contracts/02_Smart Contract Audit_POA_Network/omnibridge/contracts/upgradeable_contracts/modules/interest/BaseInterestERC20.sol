pragma solidity 0.7.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../../interfaces/IInterestReceiver.sol";
import "../../../interfaces/IInterestImplementation.sol";

/**
 * @title BaseInterestERC20
 * @dev This contract contains common logic for investing ERC20 tokens into different interest-earning protocols.
 */
abstract contract BaseInterestERC20 is IInterestImplementation {
    using SafeERC20 for IERC20;

    /**
     * @dev Ensures that caller is an EOA.
     * Functions with such modifier cannot be called from other contract (as well as from GSN-like approaches)
     */
    modifier onlyEOA {
        // solhint-disable-next-line avoid-tx-origin
        require(msg.sender == tx.origin);
        /* solcov ignore next */
        _;
    }

    /**
     * @dev Internal function transferring interest tokens to the interest receiver.
     * Calls a callback on the receiver, interest receiver is a contract.
     * @param _receiver address of the tokens receiver.
     * @param _token address of the token contract to send.
     * @param _amount amount of tokens to transfer.
     */
    function _transferInterest(
        address _receiver,
        address _token,
        uint256 _amount
    ) internal {
        require(_receiver != address(0));

        IERC20(_token).safeTransfer(_receiver, _amount);

        if (Address.isContract(_receiver)) {
            IInterestReceiver(_receiver).onInterestReceived(_token);
        }

        emit PaidInterest(_token, _receiver, _amount);
    }
}
