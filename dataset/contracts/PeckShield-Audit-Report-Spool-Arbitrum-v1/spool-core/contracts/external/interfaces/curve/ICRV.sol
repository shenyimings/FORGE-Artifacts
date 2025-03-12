// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface ICRV {
    function update_mining_parameters() external;

    function start_epoch_time_write() external returns (uint256);

    function future_epoch_time_write() external returns (uint256);

    function available_supply() external view returns (uint256);

    function mintable_in_timeframe(uint256 start, uint256 end) external view returns (uint256);

    function set_minter(address _minter) external;

    function set_admin(address _admin) external;

    function totalSupply() external view returns (uint256);

    function allowance(address _owner, address _spender) external view returns (uint256);

    function transfer(address _to, uint256 _value) external returns (bool);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);

    function approve(address _spender, uint256 _value) external returns (bool);

    function mint(address _to, uint256 _value) external returns (bool);

    function burn(uint256 _value) external returns (bool);

    function set_name(string memory _name, string memory _symbol) external;

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint256);

    function balanceOf(address arg0) external view returns (uint256);

    function minter() external view returns (address);

    function admin() external view returns (address);

    function mining_epoch() external view returns (int128);

    function start_epoch_time() external view returns (uint256);

    function rate() external view returns (uint256);
}
