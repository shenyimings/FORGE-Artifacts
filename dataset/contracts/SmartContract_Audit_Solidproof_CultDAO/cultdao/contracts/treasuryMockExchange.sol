pragma solidity 0.8.2;

contract UniswapV2RouterMock {
    uint256[] amount;
    
    constructor() public{
        uint256 temp = 1 ether;
        amount.push(temp);
        amount.push(temp);
    }
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts){
            return amount;
        }
    function WETH() external view returns (address){
        return address(this);
    }
}