pragma solidity 0.5.12;

interface ICompound {
    // uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
    function mint(uint256 mintAmount) external returns (uint256);

    // uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    // uint(Error.NO_ERROR), cTokenBalance, borrowBalance, exchangeRateMantissa
    function getAccountSnapshot(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function balanceOfUnderlying(address owner) external returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function getCash() external view returns (uint256);
}
