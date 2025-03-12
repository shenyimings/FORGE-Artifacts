pragma solidity 0.5.12;

interface WrappedToken {
    function mint(address _dst, uint256 _pie) external;

    function burn(address _src, uint256 _wad) external;

    function redeem(address _src, uint256 _pie) external;

    function getExchangeRate() external view returns (uint256);

    function getFixedInterestRate(uint256 _interval)
        external
        view
        returns (uint256);

    function originationFee() external view returns (uint256);
}
