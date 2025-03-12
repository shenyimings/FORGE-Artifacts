pragma solidity 0.5.16;

interface IComptroller {

    // ComptrollerLensInterface.sol
    // =============================
    function markets(address) external view returns (bool, uint);
    function oracle() external view returns (address);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
    function getAssetsIn(address) external view returns (address[] memory);
    function compAccrued(address) external view returns (uint);
    // Claim all the COMP accrued by holder in all markets
    function claimComp(address holder) external;
    // Claim all the COMP accrued by holder in specific markets
    function claimComp(address holder, address[] calldata cTokens) external;
    function claimComp(address[] calldata holders, address[] calldata cTokens, bool borrowers, bool suppliers) external;

    // Public storage defined in Comptroller contract
    // ===============================================
    function checkMembership(address account, address cToken) external view returns (bool);
    function closeFactorMantissa() external returns (uint256);
    function liquidationIncentiveMantissa() external returns (uint256);



    // Public/external functions defined in Comptroller contract
    // ==========================================================
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cToken) external returns (uint);

    function mintAllowed(address cToken, address minter, uint mintAmount) external returns (uint);
    function borrowAllowed(address cToken, address borrower, uint borrowAmount) external returns (uint);

    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint actualRepayAmount) external view returns (uint, uint);
}