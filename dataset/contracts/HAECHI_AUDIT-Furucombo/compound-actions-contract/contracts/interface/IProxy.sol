pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IProxy {
    function execs(address[] calldata tos, bytes32[] calldata configs, bytes[] calldata datas) external;
}
