// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum DepositActionType {
    // No deposit action
    None,
    // Deposit asset cash, depositActionAmount is specified in asset cash external precision
    DepositAsset,
    // Deposit underlying tokens that are mintable to asset cash, depositActionAmount is specified in underlying token
    // external precision
    DepositUnderlying,
    // Deposits specified asset cash external precision amount into an nToken and mints the corresponding amount of
    // nTokens into the account
    DepositAssetAndMintNToken,
    // Deposits specified underlying in external precision, mints asset cash, and uses that asset cash to mint nTokens
    DepositUnderlyingAndMintNToken,
    // Redeems an nToken balance to asset cash. depositActionAmount is specified in nToken precision. Considered a deposit action
    // because it deposits asset cash into an account. If there are fCash residuals that cannot be sold off, will revert.
    RedeemNToken,
    // Converts specified amount of asset cash balance already in Notional to nTokens. depositActionAmount is specified in
    // Notional internal 8 decimal precision.
    ConvertCashToNToken
}

struct BalanceAction {
    // Deposit action to take (if any)
    DepositActionType actionType;
    uint16 currencyId;
    // Deposit action amount must correspond to the depositActionType, see documentation above.
    uint256 depositActionAmount;
    // Withdraw an amount of asset cash specified in Notional internal 8 decimal precision
    uint256 withdrawAmountInternalPrecision;
    // If set to true, will withdraw entire cash balance. Useful if there may be an unknown amount of asset cash
    // residual left from trading.
    bool withdrawEntireCashBalance;
    // If set to true, will redeem asset cash to the underlying token on withdraw.
    bool redeemToUnderlying;
}

interface INotionalBatch {
    function batchBalanceAction(address account, BalanceAction[] calldata actions) external payable;

    function nTokenClaimIncentives() external;
}

interface INotionalView {
    function getCurrencyId(address tokenAddress) external view returns (uint16 currencyId);

    function nTokenAddress(uint16 currencyId) external view returns (address);
}

contract NotionalTest {
    address public notionalBatch = 0x1344A36A1B56144C3Bc62E7757377D288fDE0369;
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public note = 0xCFEAead4947f0705A14ec42aC3D44129E1Ef3eD5;

    constructor() {}

    function deposit() public payable {
        BalanceAction[] memory actions = new BalanceAction[](1);
        actions[0] = BalanceAction({
            actionType: DepositActionType.DepositUnderlyingAndMintNToken,
            currencyId: 3,
            depositActionAmount: 3000000,
            withdrawAmountInternalPrecision: 0,
            withdrawEntireCashBalance: false,
            redeemToUnderlying: false
        });

        IERC20(usdc).transferFrom(msg.sender, address(this), 3000000);
        IERC20(usdc).approve(notionalBatch, 11111111111111111111111111111111111111111111111111111);
        INotionalBatch(notionalBatch).batchBalanceAction(address(this), actions);

        INotionalBatch(notionalBatch).nTokenClaimIncentives();
    }
}
