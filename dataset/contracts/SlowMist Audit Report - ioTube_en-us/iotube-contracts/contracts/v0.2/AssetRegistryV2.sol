// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AssetRegistryV2 is Ownable {
    event NewAsset(uint256 indexed assetID, uint256 indexed tubeID, address indexed assetAddress);
    event AssetSetOnTube(uint256 indexed assetID, uint256 indexed tubeID, address indexed assetAddress);
    event AssetRemovedOnTube(uint256 indexed assetID, uint256 indexed tubeID, address indexed assetAddress);
    event AssetActivated(uint256 indexed id);
    event AssetDeactivated(uint256 indexed id);
    event TubeActivated(uint256 indexed id);
    event TubeDeactivated(uint256 indexed id);
    event AssetOnTubeActivated(uint256 indexed assetID, uint256 indexed tubeID, address indexed assetAddress);
    event AssetOnTubeDeactivated(uint256 indexed assetID, uint256 indexed tubeID, address indexed assetAddress);
    event OperatorGranted(address indexed operator);
    event OperatorRevoked(address indexed operator);

    struct Asset {
        address addr;
        bool active;
    }

    mapping(uint256 => bool) public activeAssetIDs;

    mapping(uint256 => bool) public activeTubeIDs;

    // tube ID + asset address => asset ID
    mapping(uint256 => mapping(address => uint256)) private tubeAndAssetToIDs;
    // asset ID + tube ID => asset address
    mapping(uint256 => mapping(uint256 => Asset)) private assets;

    uint256 private nextAssetID;

    mapping(address => bool) public operators;

    modifier onlyOperator() {
        require(operators[msg.sender], "no permission");
        _;
    }

    modifier isValidAssetID(uint256 _assetID) {
        require(_assetID > 0 && _assetID < nextAssetID, "invalid asset id");
        _;
    }

    modifier isValidTubeID(uint256 _tubeID) {
        require(_tubeID > 0, "invalid tube id");
        _;
    }

    constructor() Ownable() {
        nextAssetID = 1;
    }

    ///////////////////////////////////
    // Public Functions
    ///////////////////////////////////

    function isActive(uint256 _assetID, uint256 _tubeID) public view returns (bool) {
        if (!isActiveAssetID(_assetID) || !isActiveTubeID(_tubeID)) {
            return false;
        }
        return assets[_assetID][_tubeID].active;
    }

    function isActiveAssetID(uint256 _id) public view isValidAssetID(_id) returns (bool) {
        return activeAssetIDs[_id];
    }

    function isActiveTubeID(uint256 _id) public view isValidTubeID(_id) returns (bool) {
        return activeTubeIDs[_id];
    }

    // assetID returns the asset id of given tube id and asset address
    function assetID(uint256 _tubeID, address _assetAddr) public view isValidTubeID(_tubeID) returns (uint256) {
        return tubeAndAssetToIDs[_tubeID][_assetAddr];
    }

    function assetAddress(uint256 _assetID, uint256 _tubeID) public view isValidAssetID(_assetID) isValidTubeID(_tubeID) returns (address) {
        return assets[_assetID][_tubeID].addr;
    }

    function numOfAssets() public view returns (uint256) {
        return nextAssetID - 1;
    }

    ///////////////////////////////////
    // Operator Functions
    ///////////////////////////////////

    function newAsset(uint256 _tubeID, address _assetAddr) public onlyOperator isValidTubeID(_tubeID) {
        require(_assetAddr != address(0), "invalid asset address");
        require(assetID(_tubeID, _assetAddr) == 0, "duplicate asset");
        uint256 id = nextAssetID;
        tubeAndAssetToIDs[_tubeID][_assetAddr] = id;
        assets[id][_tubeID] = Asset(_assetAddr, false);
        nextAssetID++;
        emit NewAsset(id, _tubeID, _assetAddr);
    }

    function setAssetOnTube(
        uint256 _assetID,
        uint256 _tubeID,
        address _assetAddr
    ) public onlyOperator isValidAssetID(_assetID) isValidTubeID(_tubeID) {
        require(assetID(_tubeID, _assetAddr) == 0 && _assetAddr != address(0), "invalid asset");
        require(assetAddress(_assetID, _tubeID) == address(0), "invalid operation");
        tubeAndAssetToIDs[_tubeID][_assetAddr] = _assetID;
        assets[_assetID][_tubeID] = Asset(_assetAddr, false);
        emit AssetSetOnTube(_assetID, _tubeID, _assetAddr);
    }

    function removeAssetOnTube(
        uint256 _assetID,
        uint256 _tubeID
    ) public onlyOperator {
        address assetAddr = assetAddress(_assetID, _tubeID);
        require(assetAddr != address(0), "not exist");
        delete tubeAndAssetToIDs[_tubeID][assetAddr];
        delete assets[_assetID][_tubeID];
        emit AssetRemovedOnTube(_assetID, _tubeID, assetAddr);
    }

    function activateAsset(uint256 _id) external onlyOperator isValidAssetID(_id) {
        require(activeAssetIDs[_id] == false, "already activated");
        activeAssetIDs[_id] = true;
        emit AssetActivated(_id);
    }

    function deactivateAsset(uint256 _id) external onlyOperator isValidAssetID(_id) {
        require(activeAssetIDs[_id], "already deactivated");
        activeAssetIDs[_id] = false;
        emit AssetDeactivated(_id);
    }

    function activateTube(uint256 _id) external onlyOperator isValidTubeID(_id) {
        require(activeTubeIDs[_id] == false, "already activated");
        activeTubeIDs[_id] = true;
        emit TubeActivated(_id);
    }

    function deactivateTube(uint256 _id) external onlyOperator isValidTubeID(_id) {
        require(activeTubeIDs[_id], "already deactivated");
        activeTubeIDs[_id] = false;
        emit TubeDeactivated(_id);
    }

    function activateAssetOnTube(uint256 _assetID, uint256 _tubeID) external onlyOperator isValidAssetID(_assetID) isValidTubeID(_tubeID) {
        Asset storage asset = assets[_assetID][_tubeID];
        require(asset.addr != address(0), "asset not registered");
        require(asset.active == false, "already activated");
        asset.active = true;
        emit AssetOnTubeActivated(_assetID, _tubeID, asset.addr);
    }

    function deactivateAssetOnTube(uint256 _assetID, uint256 _tubeID) external onlyOperator isValidAssetID(_assetID) isValidTubeID(_tubeID) {
        Asset storage asset = assets[_assetID][_tubeID];
        require(asset.addr != address(0), "asset not registered");
        require(asset.active, "already activated");
        asset.active = false;
        emit AssetOnTubeDeactivated(_assetID, _tubeID, asset.addr);
    }

    ///////////////////////////////////
    // Owner Functions
    ///////////////////////////////////

    function grant(address _account) public onlyOwner {
        require(!operators[_account], "already an operator");
        operators[_account] = true;
        emit OperatorGranted(_account);
    }

    function revoke(address _account) public onlyOwner {
        require(operators[_account], "not an operator");
        operators[_account] = false;
        emit OperatorRevoked(_account);
    }
}
