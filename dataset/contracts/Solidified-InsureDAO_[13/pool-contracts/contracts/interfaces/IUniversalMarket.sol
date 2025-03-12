pragma solidity ^0.6.0;

interface IUniversalMarket {
    function initialize(
        address _owner,
        string calldata _metaData,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256[] calldata _conditions,
        address[] calldata _references
    ) external returns (bool);

    function setPaused(bool state) external;
    function changeMetadata(string calldata _metadata) external;
}
