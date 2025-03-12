import "../Interfaces.sol";

contract MockUniswapV2Router02 is IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) override external payable returns (uint amountToken, uint amountETH, uint liquidity){

	}
}