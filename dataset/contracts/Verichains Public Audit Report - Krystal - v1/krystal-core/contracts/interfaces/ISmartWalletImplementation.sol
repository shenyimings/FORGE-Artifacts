pragma solidity 0.7.6;
pragma abicoder v2;

import "@kyber.network/utils-sc/contracts/IERC20Ext.sol";

interface ISmartWalletImplementation {
    enum FeeMode {
        FROM_SOURCE,
        FROM_DEST,
        BY_PROTOCOL
    }

    event Swap(
        address indexed trader,
        address indexed swapContract,
        address[] tradePath,
        uint256 srcAmount,
        uint256 destAmount,
        uint256 platformFee,
        address platformWallet
    );

    event SwapAndDeposit(
        address indexed trader,
        address indexed swapContract,
        address indexed lendingContract,
        address[] tradePath,
        uint256 srcAmount,
        uint256 destAmount,
        uint256 platformFee,
        address platformWallet
    );

    event WithdrawFromLending(
        address indexed trader,
        address indexed lendingContract,
        IERC20Ext token,
        uint256 amount,
        uint256 minReturn,
        uint256 actualReturnAmount
    );

    event SwapAndRepay(
        address indexed trader,
        address indexed swapContract,
        address indexed lendingContract,
        address[] tradePath,
        uint256 srcAmount,
        uint256 destAmount,
        uint256 payAmount,
        uint256 platformFee,
        address platformWallet
    );

    /// @param swapContract swap contract
    /// @param srcAmount amount of src token
    /// @param tradePath path of the trade on Uniswap
    /// @param platformFee fee if swapping feeMode = platformFee / BPS, feeBps = platformFee % BPS
    /// @param extraArgs extra data needed for swap on particular platforms
    struct GetExpectedReturnParams {
        address payable swapContract;
        uint256 srcAmount;
        address[] tradePath;
        FeeMode feeMode;
        uint256 feeBps;
        bytes extraArgs;
    }

    function getExpectedReturn(GetExpectedReturnParams calldata params)
        external
        view
        returns (uint256 destAmount, uint256 expectedRate);

    /// @param swapContract swap contract
    /// @param srcAmount amount of src token
    /// @param minDestAmount minimal accepted dest amount
    /// @param tradePath path of the trade on Uniswap
    /// @param feeMode fee mode
    /// @param feeBps fee bps
    /// @param platformWallet wallet to receive fee
    /// @param extraArgs extra data needed for swap on particular platforms
    struct SwapParams {
        address payable swapContract;
        uint256 srcAmount;
        uint256 minDestAmount;
        address[] tradePath;
        FeeMode feeMode;
        uint256 feeBps;
        address payable platformWallet;
        bytes extraArgs;
    }

    function swap(SwapParams calldata params) external payable returns (uint256 destAmount);

    /// @param swapContract swap contract
    /// @param lendingContract lending contract
    /// @param srcAmount amount of src token
    /// @param minDestAmount minimal accepted dest amount
    /// @param tradePath path of the trade on Uniswap
    /// @param feeMode fee mode
    /// @param feeBps fee bps
    /// @param platformWallet wallet to receive fee
    /// @param extraArgs extra data needed for swap on particular platforms
    struct SwapAndDepositParams {
        address payable swapContract;
        address payable lendingContract;
        uint256 srcAmount;
        uint256 minDestAmount;
        address[] tradePath;
        FeeMode feeMode;
        uint256 feeBps;
        address payable platformWallet;
        bytes extraArgs;
    }

    function swapAndDeposit(SwapAndDepositParams calldata params)
        external
        payable
        returns (uint256 destAmount);

    /// @param lendingContract lending contract to withdraw token
    /// @param token underlying token to withdraw, e.g ETH, USDT, DAI
    /// @param amount amount of cToken (COMPOUND) or aToken (AAVE) to withdraw
    /// @param minReturn minimum amount of underlying tokens to return
    struct WithdrawFromLendingPlatformParams {
        address payable lendingContract;
        IERC20Ext token;
        uint256 amount;
        uint256 minReturn;
    }

    function withdrawFromLendingPlatform(WithdrawFromLendingPlatformParams calldata params)
        external
        returns (uint256 returnedAmount);

    /// @param swapContract swap contract
    /// @param lendingContract lending contract
    /// @param srcAmount amount of src token
    /// @param payAmount: amount that user wants to pay, if the dest amount (after swap) is higher,
    ///     the remain amount will be sent back to user's wallet
    /// @param tradePath path of the trade on Uniswap
    /// @param rateMode rate mode for aave v2
    /// @param feeMode fee mode
    /// @param feeBps fee bps
    /// @param platformWallet wallet to receive fee
    /// @param extraArgs extra data needed for swap on particular platforms
    struct SwapAndRepayParams {
        address payable swapContract;
        address payable lendingContract;
        uint256 srcAmount;
        uint256 payAmount;
        address[] tradePath;
        uint256 rateMode; // for aave v2
        FeeMode feeMode;
        uint256 feeBps;
        address payable platformWallet;
        bytes extraArgs;
    }

    function swapAndRepay(SwapAndRepayParams calldata params)
        external
        payable
        returns (uint256 destAmount);

    function claimPlatformFees(address[] calldata platformWallets, IERC20Ext[] calldata tokens)
        external;
}
