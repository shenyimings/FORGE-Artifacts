// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./Token.sol";
/**
 * @notice Contains all information necessary to execute a PrivateOffer.
 */
struct PrivateOfferArguments {
    /// address holding the currency. Must have given sufficient allowance to this contract.
    address currencyPayer;
    /// address receiving the tokens. Must have sufficient attributes in AllowList to be able to receive tokens or the TRANSFERER role.
    address tokenReceiver;
    /// address receiving the payment in currency.
    address currencyReceiver;
    /// amount of tokens to be bought.
    uint256 tokenAmount;
    /// price company and investor agreed on, see docs/price.md.
    uint256 tokenPrice;
    /// timestamp after which the invitation is no longer valid.
    uint256 expiration;
    /// currency used for payment
    IERC20 currency;
    /// token to be bought
    Token token;
}

/**
 * @title PrivateOffer
 * @author malteish, cjentzsch
 * @notice This contract represents the offer to buy an amount of tokens at a preset price. It is created for a specific buyer and can only be claimed once and only by that buyer.
 *     All parameters of the invitation (currencyPayer, tokenReceiver, currencyReceiver, tokenAmount, tokenPrice, currency, token) are immutable (see description of CREATE2).
 *     It is likely a company will create many PrivateOffers for specific investors to buy their one token.
 *     The use of CREATE2 (https://docs.openzeppelin.com/cli/2.8/deploying-with-create2) enables this invitation to be privacy preserving until it is accepted through
 *     granting of an allowance to the PrivateOffer's future address and deployment of the PrivateOffer.
 * @dev This contract is deployed using CREATE2 (https://docs.openzeppelin.com/cli/2.8/deploying-with-create2), using a deploy factory. That makes the future address of this contract
 *     deterministic: it can be computed from the parameters of the invitation. This allows the company and buyer to grant allowances to the future address of this contract
 *     before it is deployed.
 *     The process of deploying this contract is as follows:
 *     1. Company and investor agree on the terms of the invitation (currencyPayer, tokenReceiver, currencyReceiver, tokenAmount, tokenPrice, currency, token)
 *         and a salt (used for deployment only).
 *     2. With the help of a deploy factory, the company computes the future address of the PrivateOffer contract.
 *     3. The company grants a token minting allowance of amount to the future address of the PrivateOffer contract.
 *     4. The investor grants a currency allowance of amount*tokenPrice / 10**tokenDecimals to the future address of the PrivateOffer contract, using their currencyPayer address.
 *     5. Finally, company, buyer or anyone else deploys the PrivateOffer contract using the deploy factory.
 *     Because all of the execution logic is in the constructor, the deployment of the PrivateOffer contract is the last step. During the deployment, the newly
 *     minted tokens will be transferred to the buyer and the currency will be transferred to the company's receiver address.
 */
contract PrivateOffer {
    using SafeERC20 for IERC20;

    /**
     * @notice Emitted when a PrivateOffer is deployed. `currencyPayer` paid for `tokenAmount` tokens at `tokenPrice` per token. The tokens were minted to `tokenReceiver`.
     *    The token is deployed at `token` and the currency is `currency`.
     * @param currencyPayer address that paid the currency
     * @param tokenReceiver address that received the tokens
     * @param tokenAmount amount of tokens that were bought
     * @param tokenPrice price company and investor agreed on, see docs/price.md.
     * @param currency currency used for payment
     * @param token contract of the token that was bought
     */
    event Deal(
        address indexed currencyPayer,
        address indexed tokenReceiver,
        uint256 tokenAmount,
        uint256 tokenPrice,
        IERC20 currency,
        Token indexed token
    );

    constructor(PrivateOfferArguments memory _arguments) {
        require(_arguments.currencyPayer != address(0), "_arguments.currencyPayer can not be zero address");
        require(_arguments.tokenReceiver != address(0), "_arguments.tokenReceiver can not be zero address");
        require(_arguments.currencyReceiver != address(0), "_arguments.currencyReceiver can not be zero address");
        require(_arguments.tokenPrice != 0, "_arguments.tokenPrice can not be zero"); // a simple mint from the token contract will do in that case
        require(block.timestamp <= _arguments.expiration, "Deal expired");

        // rounding up to the next whole number. Investor is charged up to one currency bit more in case of a fractional currency bit.
        uint256 currencyAmount = Math.ceilDiv(
            _arguments.tokenAmount * _arguments.tokenPrice,
            10 ** _arguments.token.decimals()
        );

        IFeeSettingsV2 feeSettings = _arguments.token.feeSettings();
        uint256 fee = feeSettings.privateOfferFee(currencyAmount, address(_arguments.token));
        if (fee != 0) {
            _arguments.currency.safeTransferFrom(
                _arguments.currencyPayer,
                feeSettings.privateOfferFeeCollector(address(_arguments.token)),
                fee
            );
        }
        _arguments.currency.safeTransferFrom(
            _arguments.currencyPayer,
            _arguments.currencyReceiver,
            (currencyAmount - fee)
        );

        _arguments.token.mint(_arguments.tokenReceiver, _arguments.tokenAmount);

        emit Deal(
            _arguments.currencyPayer,
            _arguments.tokenReceiver,
            _arguments.tokenAmount,
            _arguments.tokenPrice,
            _arguments.currency,
            _arguments.token
        );
    }
}
