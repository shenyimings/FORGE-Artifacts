pragma solidity 0.5.12;

interface IHandler {
    function deposit(address _token, uint256 _amount)
        external
        returns (uint256);

    function withdraw(address _token, uint256 _amount)
        external
        returns (uint256);

    function getRealBalance(address _token) external returns (uint256);

    function getRealLiquidity(address _token) external returns (uint256);

    function getBalance(address _token) external view returns (uint256);

    function getLiquidity(address _token) external view returns (uint256);

    function paused() external view returns (bool);

    function tokenIsEnabled(address _underlyingToken)
        external
        view
        returns (bool);
}
