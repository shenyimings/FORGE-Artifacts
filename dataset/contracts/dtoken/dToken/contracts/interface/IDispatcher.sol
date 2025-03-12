pragma solidity 0.5.12;

interface IDispatcher {
    function getHandlers()
        external
        view
        returns (address[] memory, uint256[] memory);

    function getDepositStrategy(uint256 _amount)
        external
        view
        returns (address[] memory, uint256[] memory);

    function getWithdrawStrategy(address _token, uint256 _amount)
        external
        returns (address[] memory, uint256[] memory);

    function isHandlerActive(address _handler) external view returns (bool);

    function defaultHandler() external view returns (address);
}
