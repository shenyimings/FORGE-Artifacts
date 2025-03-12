pragma solidity 0.8.0;

interface IWTokenVault {
    event WTokensLocked(
        address ammAddress,
        address redeemer,
        uint256 expirationId,
        uint256 lpSharesMinted
    );
    event LpSharesRedeemed(
        address ammAddress,
        address redeemer,
        uint256 expirationId,
        uint256 numShares,
        uint256 collateralAmount
    );
    event CollateralLocked(
        address ammAddress,
        uint64 seriesId,
        uint256 collateralAmount,
        uint256 wTokenAmount
    );

    function getWTokenBalance(address poolAddress, uint64 seriesId)
        external
        view
        returns (uint256);

    function lockActiveWTokens(
        uint256 lpTokenAmount,
        uint256 lpTokenSupply,
        address redeemer,
        uint256 volatility
    ) external;

    function redeemCollateral(uint256 expirationId, address redeemer)
        external
        returns (uint256);

    function lockCollateral(
        uint64 seriesId,
        uint256 collateralAmount,
        uint256 wTokenAmount
    ) external;
}
