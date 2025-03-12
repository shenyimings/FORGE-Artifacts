// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

/**
 * @title KEI Finance Presale Contract.
 * @author KEI Finance
 * @notice A fund raising contract for liquidity pools or initial token offering.
 */
interface IPresale {
    /**
     * @notice Emitted when the {PresaleConfig} is updated.
     * @param prevConfig The previous presale configuration.
     * @param newConfig The new presale configuration.
     * @param sender The message sender that triggered the event.
     */
    event ConfigUpdated(PresaleConfig prevConfig, PresaleConfig newConfig, address indexed sender);

    /**
     * @notice Emitted when the {RoundConfig} array is updated.
     * @param prevRounds The previous array of round configurations.
     * @param newRounds The previous array of round configurations.
     * @param prevCurrentRoundIndex The previous current round index.
     * @param newCurrentRoundIndex The new current round index.
     * @param sender The message sender that triggered the event.
     */
    event RoundsUpdated(
        RoundConfig[] prevRounds,
        RoundConfig[] newRounds,
        uint256 prevCurrentRoundIndex,
        uint256 newCurrentRoundIndex,
        address indexed sender
    );

    /**
     * @notice Emitted when a purchase in a round is made.
     * @param receiptId The ID of the receipt that this purchase is tied to.
     * @param roundIndex The round index that the purchase was made in.
     * @param amountUSD The USD value of the tokens purchased.
     * @param tokensAllocated The number of tokens allocated to the purchaser.
     */
    event Purchase(uint256 indexed receiptId, uint256 indexed roundIndex, uint256 amountUSD, uint256 tokensAllocated);

    /**
     * @notice Emitted when a purchase is made.
     * @param id The receipt ID.
     * @param purchase The purchase configuration.
     * @param receipt The receipt details.
     * @param sender The message sender that triggered the event.
     */
    event PurchaseReceipt(uint256 indexed id, PurchaseConfig purchase, Receipt receipt, address indexed sender);

    /**
     * @notice Round type - either for liquidity pool provision or for initial token issuance.
     */
    enum RoundType {
        Liquidity,
        Tokens
    }

    /**
     * @notice Presale Configuration structure.
     * @param minDepositAmount The minimum USD purchase amount.
     * @param maxUserAllocation The maximum number of tokens a user can purchase across all rounds.
     * @param startDate The unix timestamp marking the start of the presale.
     * @param endDate The unix timestamp marking the end of the presale.
     * @param withdrawTo The address that immediately receives all funds on each purchase.
     */
    struct PresaleConfig {
        uint128 minDepositAmount;
        uint128 maxUserAllocation;
        uint48 startDate;
        uint48 endDate;
        address withdrawTo;
    }

    /**
     * @notice Round Configuration structure.
     * @param tokenPrice The round token price.
     * @param tokenAllocation The number of tokens allocated for purchase in the round.
     * @param roundType The type of the round.
     */
    struct RoundConfig {
        uint256 tokenPrice;
        uint256 tokenAllocation;
        RoundType roundType;
    }

    /**
     * @notice Purchase Configuration structure.
     * @param asset The asset used to purchase the tokens.
     * @param amountAsset The amount of the asset the user intends to spend.
     * @param amountUSD The USD value of the amount of assets the user intends to spend.
     * @param account The account that will be be allocated tokens.
     * @param data Additional bytes data tied to the purchase.
     */
    struct PurchaseConfig {
        address asset;
        uint256 amountAsset;
        uint256 amountUSD;
        address account;
        bytes data;
    }

    /**
     * @notice Receipt structure.
     * @param id The receipt ID.
     * @param tokensAllocated The number of tokens allocated.
     * @param refundedAssets The number of tokens refunded.
     * @param remainingUSD The remaining USD amount that was not spent.
     * @param costAssets The number of assets spent.
     * @param costUSD The USD value of the assets spent.
     * @param usdAllocated The USD value of liquidity provided.
     */
    struct Receipt {
        uint256 id;
        uint256 tokensAllocated;
        uint256 refundedAssets;
        uint256 remainingUSD;
        uint256 costAssets;
        uint256 costUSD;
        uint256 usdAllocated;
    }

    /**
     * @notice The USDC address.
     */
    function USDC() external view returns (address);

    /**
     * @notice The DAI address.
     */
    function DAI() external view returns (address);

    /**
     * @notice The Chainlink Oracle ETH/USD address.
     */
    function ORACLE() external view returns (address);

    /**
     * @notice The 8 decimal precision used in the contract.
     */
    function PRECISION() external view returns (uint256);

    /**
     * @notice The 18 decimal USD related precision used in the contract.
     */
    function USD_PRECISION() external view returns (uint256);

    /**
     * @notice The decimal difference between USDC and `USD_PRECISION`.
     */
    function USDC_SCALE() external view returns (uint256);

    /**
     * @notice Returns the current round index.
     */
    function currentRoundIndex() external view returns (uint256);

    /**
     * @notice Returns the presale configuration.
     */
    function config() external view returns (PresaleConfig memory);

    /**
     * @notice Returns the configuration of a specific round.
     * @param roundIndex The round index to return the configuration of.
     */
    function round(uint256 roundIndex) external view returns (RoundConfig memory);

    /**
     * @notice Returns an array of all the round configurations set by the admin.
     */
    function rounds() external view returns (RoundConfig[] memory);

    /**
     * @notice Returns the number of total purchases made.
     */
    function totalPurchases() external view returns (uint256);

    /**
     * @notice Returns the number of total rounds.
     */
    function totalRounds() external view returns (uint256);

    /**
     * @notice Returns the total USD value of the funds raised.
     */
    function totalRaisedUSD() external view returns (uint256);

    /**
     * @notice Returns the number of tokens allocated in a round.
     * @param roundIndex The index of the round to return the tokens allocated in.
     */
    function roundTokensAllocated(uint256 roundIndex) external view returns (uint256);

    /**
     * @notice Returns the number of tokens allocated to a specific user across `Token` type rounds.
     * @param account The account to return the token allocation of.
     */
    function userTokensAllocated(address account) external view returns (uint256);

    /**
     * @notice Returns the USD liquidity provision balance of a user across all `Liquidity` type rounds.
     * @param account The account to return the total USD liquidity provision balance of.
     */
    function userUSDAllocated(address account) external view returns (uint256);

    /**
     * @notice Returns the ETH price from the Chainlink Oracle.
     * @dev Price is returned in 8 decimals.
     */
    function ethPrice() external view returns (uint256);

    /**
     * @notice Returns the USD value of an input amount of ETH using the Oracle for conversion.
     * @param amount The amount of ETH to return the USD value of.
     * @return _usdAmount The USD value of `amount`.
     */
    function ethToUsd(uint256 amount) external view returns (uint256 _usdAmount);

    /**
     * @notice Returns the conversion from ETH to tokens.
     * @param amount The amount of ETH to convert.
     * @param price The price of tokens - based on the current round price set by admin.
     * @return _tokenAmount The number of tokens that are equal to the value of input ETH.
     */
    function ethToTokens(uint256 amount, uint256 price) external view returns (uint256 _tokenAmount);

    /**
     * @notice Returns the conversion from USD to tokens.
     * @param amount The amount of USD to convert.
     * @param price The price of tokens - based on the current round price set by admin.
     * @return _tokenAmount The number of tokens that are equal to the value of input USD.
     */
    function usdToTokens(uint256 amount, uint256 price) external pure returns (uint256 _tokenAmount);

    /**
     * @notice Returns the conversion from tokens to USD.
     * @param amount The amount of tokens to convert.
     * @param price The price of tokens - based on the current round price set by admin.
     * @return _usdAmount The USD value of the input tokens.
     */
    function tokensToUSD(uint256 amount, uint256 price) external pure returns (uint256 _usdAmount);

    /**
     * @notice Pauses the contract.
     * @custom:emits Paused
     * @custom:requirement The function caller must be the owner of the contract.
     * @custom:requirement The contract must be unpaused.
     */
    function pause() external;

    /**
     * @notice Unpauses the contract.
     * @custom:emits Unpaused
     * @custom:requirement The function caller must be the owner of the contract.
     * @custom:requirement The contract must be paused.
     */
    function unpause() external;

    /**
     * @notice Sets the presale configuration.
     * @param newConfig The new presale configuration.
     * @custom:emits ConfigUpdated
     * @custom:requirement The function caller must be the owner of the contract.
     * @custom:requirement The new presale configuration `startDate` must be less than the `endDate`.
     * @custom:requirement The new presale configuration `withdrawTo` address must not be address zero.
     */
    function setConfig(PresaleConfig calldata newConfig) external;

    /**
     * @notice Sets the array of round configurations.
     * @param newRounds The array of new round configurations.
     * @custom:emits RoundsUpdated
     */
    function setRounds(RoundConfig[] calldata newRounds) external;

    /**
     * @notice Purchases tokens for `account` or increases a user's liquidity provision balance, by spending ETH - depending on the round type.
     * @param account The account to be allocated the purchased tokens or increased liquidity provision balance.
     * @param data Additional bytes data tied to the purchase.
     * @custom:emits Purchase - for each round that the purchase is made within
     * @custom:emits PurchaseReceipt
     * @custom:requirement The contract must not be paused.
     * @custom:requirement The current block timestamp must be grater or equal to the presale configuration `startDate`.
     * @custom:requirement The current block timestamp must be less than or equal to the presale configuration `endDate`.
     * @custom:requirement The USD value of the intended purchase amount must be greater than zero or the presale configuration minimum deposit amount is equal to zero.
     * @custom:requirement Either the refunded purchase asset amount or tokens allocated must be equal to zero, or the refunded purchase asset amount is not equal to the
     * intended purchase asset amount.
     * @custom:requirement The number of tokens allocated to `account` must be greater than zero.
     * @return The receipt.
     */
    function purchase(address account, bytes memory data) external payable returns (Receipt memory);

    /**
     * @notice Purchases tokens for `account` or increases a user's liquidity provision balance, by spending USDC - depending on the round type.
     * @param account The account to be allocated the purchased tokens or increased liquidity provision balance.
     * @param amount The amount of USDC intended to be spent.
     * @param data Additional bytes data tied to the purchase.
     * @custom:emits Purchase - for each round that the purchase is made within
     * @custom:emits PurchaseReceipt
     * @custom:requirement The contract must not be paused.
     * @custom:requirement The current block timestamp must be grater or equal to the presale configuration `startDate`.
     * @custom:requirement The current block timestamp must be less than or equal to the presale configuration `endDate`.
     * @custom:requirement The USD value of the intended purchase amount must be greater than zero or the presale configuration minimum deposit amount is equal to zero.
     * @custom:requirement Either the refunded purchase asset amount or tokens allocated must be equal to zero, or the refunded purchase asset amount is not equal to the
     * intended purchase asset amount.
     * @custom:requirement The number of tokens allocated to `account` must be greater than zero.
     * @return The receipt.
     */
    function purchaseUSDC(address account, uint256 amount, bytes calldata data) external returns (Receipt memory);

    /**
     * @notice Purchases tokens for `account` or increases a user's liquidity provision balance, by spending DAI - depending on the round type.
     * @param account The account to be allocated the purchased tokens or increased liquidity provision balance.
     * @param amount The amount of DAI intended to be spent.
     * @param data Additional bytes data tied to the purchase.
     * @custom:emits Purchase - for each round that the purchase is made within
     * @custom:emits PurchaseReceipt
     * @custom:requirement The contract must not be paused.
     * @custom:requirement The current block timestamp must be grater or equal to the presale configuration `startDate`.
     * @custom:requirement The current block timestamp must be less than or equal to the presale configuration `endDate`.
     * @custom:requirement The USD value of the intended purchase amount must be greater than zero or the presale configuration minimum deposit amount is equal to zero.
     * @custom:requirement Either the refunded purchase asset amount or tokens allocated must be equal to zero, or the refunded purchase asset amount is not equal to the
     * intended purchase asset amount.
     * @custom:requirement The number of tokens allocated to `account` must be greater than zero.
     * @return The receipt.
     */
    function purchaseDAI(address account, uint256 amount, bytes calldata data) external returns (Receipt memory);

    /**
     * @notice Allocates tokens or liquidity provision balance for `account` without the need for spending any tokens.
     * @param account The account to be allocated the purchased tokens or increase liquidity provision balance.
     * @param amountUSD The USD value of the intended allocation of tokens or liquidity provision.
     * @param data Additional bytes data tied to the purchase.
     * @custom:emits Purchase - for each round that the purchase is made within
     * @custom:emits PurchaseReceipt
     * @custom:requirement The function caller must be the contract owner.
     * @custom:requirement The contract must not be paused.
     * @custom:requirement The current block timestamp must be grater or equal to the presale configuration `startDate`.
     * @custom:requirement The current block timestamp must be less than or equal to the presale configuration `endDate`.
     * @custom:requirement The USD value of the intended purchase amount must be greater than zero or the presale configuration minimum deposit amount is equal to zero.
     * @custom:requirement Either the refunded purchase asset amount or tokens allocated must be equal to zero, or the refunded purchase asset amount is not equal to the
     * intended purchase asset amount.
     * @custom:requirement The number of tokens allocated to `account` must be greater than zero.
     * @return The receipt.
     */
    function allocate(address account, uint256 amountUSD, bytes calldata data) external returns (Receipt memory);
}
