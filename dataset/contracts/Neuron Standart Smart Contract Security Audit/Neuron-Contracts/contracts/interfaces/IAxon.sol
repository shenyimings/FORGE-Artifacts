pragma solidity 0.8.9;

interface IAxon {
    function balanceOf(address addr, uint256 _t) external view returns (uint256);

    function balanceOf(address addr) external view returns (uint256);

    function balanceOfAt(address addr, uint256 _block) external view returns (uint256);

    function totalSupply(uint256 t) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
