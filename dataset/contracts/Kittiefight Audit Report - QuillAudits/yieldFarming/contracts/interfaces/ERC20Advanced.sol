pragma solidity ^0.5.5;


/**
 * @title ERC20 Advanced interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface ERC20Advanced {
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
