//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import "./interface/IRedeemPool.sol";
import "../Token/interface/IToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @author Polytrade
 * @title RedeemPool
 */
contract RedeemPool is IRedeemPool, AccessControl {
    using SafeERC20 for IToken;

    IToken public immutable stable;
    IToken public immutable tStable;

    bytes32 public constant LENDER_POOL = keccak256("LENDER_POOL");

    constructor(address _stableAddress, address _tStableAddress) {
        stable = IToken(_stableAddress);
        tStable = IToken(_tStableAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice exchange tStable token for the stable token
     * @dev users can directly call this function using EOA after approving `amount`
     * @param amount, the number of tokens to be exchanged
     */
    function redeemStable(uint amount) external {
        _redeemStable(msg.sender, amount);
    }

    /**
     * @notice exchange tStable token for the stable token
     * @dev burns the tStable from msg.sender and sends stable to `account`
     * @param amount, the number of tokens to be exchanged
     * @param account, address of the account that will receive the stable token
     */
    function redeemStableFor(address account, uint amount)
        external
        onlyRole(LENDER_POOL)
    {
        _redeemStable(account, amount);
    }

    /**
     * @notice exchange tStable token for the stable token
     * @dev Transfers the approved tStable token from account to redeem pool and burn it
     * @dev Transfers the  equivalent amount of stable token from redeem pool to account
     * @param amount, the number of tokens to be exchanged
     * @param account, address of the account that will receive the stable token
     *
     * Requirements:
     *
     * - `amount` should be greater than zero
     * - `amount` must be approved from the tStable token contract for the RedeemPool contract
     * - `amount` must be less than balanceOf stable token of Redeem Pool
     *
     * Emits {StableWithdrawn} event
     */
    function _redeemStable(address account, uint amount) private {
        require(amount > 0, "Amount is 0");
        require(
            tStable.balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );
        require(
            stable.balanceOf(address(this)) >= amount,
            "Insufficient balance in pool"
        );
        tStable.burnFrom(msg.sender, amount);
        stable.safeTransfer(account, amount);
        emit StableWithdrawn(account, amount);
    }
}
