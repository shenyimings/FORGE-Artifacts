// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

interface ICurveToken {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function balanceOf(address _owner) external view returns (uint256);

    function allowance(address _owner, address _spender) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function minter() external view returns (address);

    function nonces(address owner) external view returns (uint256);

    function transfer(address _to, uint256 _value) external returns (bool);

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

    function approve(address _spender, uint256 _value) external returns (bool);

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function increaseAllowance(address _spender, uint256 _addedValue) external returns (bool);

    function decreaseAllowance(address _spender, uint256 _subtractedValue) external returns (bool);

    function mint(address _to, uint256 _value) external returns (bool);

    function mint_relative(address _to, uint256 frac) external returns (uint256);

    function burnFrom(address _to, uint256 _value) external returns (bool);

    function decimals() external view returns (uint256);

    function version() external view returns (uint256);

    function initialize(string memory _name, string memory _symbol, address _pool) external;
}
