pragma solidity >= 0.8.0;
// interface just for masterchef
interface IMetaVillToken {
    function transferTaxRate() external view returns(uint16);
    function balanceOf(address account) external  view returns (uint256);
    function totalSupply() external  view returns (uint256);
    function name() external  view returns (string memory);
    function decimals() external  view returns (uint8);
    function transfer(address recipient, uint256 amount) external  returns (bool);
    function mint(address to, uint256 amount) external;
}