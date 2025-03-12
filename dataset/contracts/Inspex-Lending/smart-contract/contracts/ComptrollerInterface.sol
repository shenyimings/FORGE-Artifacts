pragma solidity ^0.5.16;

contract ComptrollerInterfaceG1 {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata wlTokens) external returns (uint[] memory);
    function exitMarket(address wlToken) external returns (uint);

    /*** Policy Hooks ***/

    function mintAllowed(address wlToken, address minter, uint mintAmount) external returns (uint);
    function mintVerify(address wlToken, address minter, uint mintAmount, uint mintTokens) external;

    function redeemAllowed(address wlToken, address redeemer, uint redeemTokens) external returns (uint);
    function redeemVerify(address wlToken, address redeemer, uint redeemAmount, uint redeemTokens) external;

    function borrowAllowed(address wlToken, address borrower, uint borrowAmount) external returns (uint);
    function borrowVerify(address wlToken, address borrower, uint borrowAmount) external;

    function repayBorrowAllowed(
        address wlToken,
        address payer,
        address borrower,
        uint repayAmount) external returns (uint);
    function repayBorrowVerify(
        address wlToken,
        address payer,
        address borrower,
        uint repayAmount,
        uint borrowerIndex) external;

    function liquidateBorrowAllowed(
        address wlTokenBorrowed,
        address wlTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount) external returns (uint);
    function liquidateBorrowVerify(
        address wlTokenBorrowed,
        address wlTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount,
        uint seizeTokens) external;

    function seizeAllowed(
        address wlTokenCollateral,
        address wlTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) external returns (uint);
    function seizeVerify(
        address wlTokenCollateral,
        address wlTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) external;

    function transferAllowed(address wlToken, address src, address dst, uint transferTokens) external returns (uint);
    function transferVerify(address wlToken, address src, address dst, uint transferTokens) external;

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address wlTokenBorrowed,
        address wlTokenCollateral,
        uint repayAmount) external view returns (uint, uint);

}


contract ComptrollerInterface is ComptrollerInterfaceG1 {
}

interface IComptroller {
    /*** Treasury Data ***/
    function treasuryAddress() external view returns (address);
    function treasuryPercent() external view returns (uint);
}
