// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "./IRouter.sol";
import "./IReserve.sol";

interface IBuyback {
    function router() external view returns (IRouter);

    function reserve() external view returns (IReserve);

    function money() external view returns (address);

    function setReserve(address _newAddress) external;

    function updateMoney(address _newAddress) external;

    function updateRouter(address _newAddress) external;

    function swapTokens(
        uint256 minOut,
        address token,
        address[] memory path
    ) external returns (uint256 amountOut);

    function removeLiquidity(
        address _token0,
        address _token1,
        uint256 _minToken0Out,
        uint256 _minToken1Out
    ) external returns (uint256 amount0Out, uint256 amount1Out);

    function transferMoneyToReserve() external returns (uint256 toTransfer);

    function inCaseTokensGetStuck(address _token, address payable _to) external;
}
