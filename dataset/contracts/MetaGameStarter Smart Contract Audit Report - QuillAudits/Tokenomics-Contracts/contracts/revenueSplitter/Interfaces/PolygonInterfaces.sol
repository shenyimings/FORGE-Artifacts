pragma solidity ^0.8.0.0;


interface IPolygonBridgeExit {
    function exit(bytes memory data) external;
}

interface IPolygonTokenPOS {
    function withdraw(uint256 amount) external;
}