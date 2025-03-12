/// This contract is for testing purposes only and will never be deployed

pragma solidity 0.5.16;

contract MockOracle {

  uint256 priceAUSC = 1;
  uint256 priceXAU = 1;

  constructor () public {
  }

  function setAUSCPrice(uint256 price) external {
    priceAUSC = price;
  }

  function setXAUPrice(uint256 price) external {
    priceXAU = price;
  }

  function getPriceAUSC() public view returns (bool, uint256) {
    return (true, priceAUSC);
  }

  function getPriceXAU() public view returns (bool, uint256) {
    return (true, priceXAU);
  }
}

