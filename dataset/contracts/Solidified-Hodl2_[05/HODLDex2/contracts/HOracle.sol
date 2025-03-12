pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

interface IUniswap {
    function getReserves() external view returns(uint112, uint112, uint32);
}

interface IHOracle {
   function read() external view returns(uint ethUsd18); 
}

contract HOracle is IHOracle {

    IUniswap uniswap = IUniswap(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    uint constant PRECISION = 10 ** 18;
    uint constant UNISWAP_SHIFT = 10 ** 12;
    
    function read() public view override returns(uint ethUsd18) {
        (uint112 uniswapReserve0, uint112 uniswapReserve1, /*uint32 timeStamp*/) = uniswap.getReserves();
        ethUsd18 = (uint(uniswapReserve0) * PRECISION * UNISWAP_SHIFT) / (uniswapReserve1);
    }
}
