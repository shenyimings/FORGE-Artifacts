// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AssetRegistry is Ownable {
    event NewOriginalAsset(uint256 indexed tubeID, address indexed asset, uint256 indexed id);
    event AssetAddedOnTube(uint256 indexed id, uint256 indexed tubeID, address asset);
    event AssetRemovedOnTube(uint256 indexed id, uint256 indexed tubeID, address asset);
    event AssetActivated(uint256 indexed id, uint256 indexed tubID);
    event AssetDeactivated(uint256 indexed id, uint256 indexed tubeID);
    event TubeActivated(uint256 indexed tubID);
    event TubeDeactivated(uint256 indexed tubeID);
    event OperatorGranted(address indexed operator);
    event OperatorRevoked(address indexed operator);

    struct Asset {
        uint256 tubeID;
        address asset;
        bool active;
    }

    Asset[] private originalAssets;
    // tubeID + asset => assetID
    mapping(uint256 => mapping(address => uint256)) private originalAssetIDs;
    // assetID + shadow tubeID => shadow asset
    mapping(uint256 => mapping(uint256 => Asset)) private shadowAssets;
    // shadow tubeID + shadow asset => assetID
    mapping(uint256 => mapping(address => uint256)) private shadowAssetIDs;
    // tubes which are banned
    mapping(uint256 => bool) public bannedTubeIDs;

    mapping(address => bool) public operators;

    modifier onlyOperator() {
        require(operators[msg.sender], "no permission");
        _;
    }

    // assetID returns the asset id of given tube id and asset address
    function assetID(uint256 _tubeID, address _asset) public view returns (uint256) {
        uint256 id = originalAssetIDs[_tubeID][_asset];
        if (id == 0) {
            id = shadowAssetIDs[_tubeID][_asset];
        }
        return id;
    }

    function originalAssetByID(uint256 _assetID) public view returns (Asset memory) {
        require(_assetID > 0 && _assetID <= originalAssets.length, "invalid asset id");
        return originalAssets[_assetID - 1];
    }

    function numOfAssets() public view returns (uint256) {
        return originalAssets.length;
    }

    function assetOnTubeByID(uint256 _assetID, uint256 _tubeID) public view returns (Asset memory) {
        Asset memory originalAsset = originalAssetByID(_assetID);
        if (originalAsset.tubeID == _tubeID) {
            return originalAsset;
        }
        return shadowAssets[_assetID][_tubeID];
    }

    function assetOnTube(
        uint256 _srcTubeID,
        address _srcAsset,
        uint256 _dstTubeID
    ) public view returns (Asset memory) {
        return assetOnTubeByID(assetID(_srcTubeID, _srcAsset), _dstTubeID);
    }

    function addOriginalAsset(uint256 _tubeID, address _asset) public onlyOperator returns (uint256) {
        require(_tubeID > 0 && _asset != address(0), "invalid parameter");
        uint256 id = assetID(_tubeID, _asset);
        if (id == 0) {
            originalAssets.push(Asset(_tubeID, _asset, true));
            id = originalAssets.length;
            originalAssetIDs[_tubeID][_asset] = id;
            emit NewOriginalAsset(_tubeID, _asset, id);
        }
        return id;
    }

    function addAssetOnTube(
        uint256 _assetID,
        uint256 _tubeID,
        address _asset
    ) public onlyOperator {
        require(
            _tubeID > 0 && _asset != address(0) && _assetID > 0 && _assetID <= originalAssets.length,
            "invalid parameter"
        );
        require(assetID(_tubeID, _asset) == 0, "invalid asset");
        require(shadowAssets[_assetID][_tubeID].asset == address(0), "invalid asset");
        shadowAssets[_assetID][_tubeID] = Asset(_tubeID, _asset, true);
        shadowAssetIDs[_tubeID][_asset] = _assetID;
        emit AssetAddedOnTube(_assetID, _tubeID, _asset);
    }

    function removeAssetOnTube(
        uint256 _assetID,
        uint256 _tubeID
    ) public onlyOperator {
        address asset = shadowAssets[_assetID][_tubeID].asset;
        require(asset != address(0), "not exist");
        delete shadowAssetIDs[_tubeID][asset];
        delete shadowAssets[_assetID][_tubeID];
        emit AssetRemovedOnTube(_assetID, _tubeID, asset);
    }

    function activateAsset(uint256 _assetID, uint256 _tubeID) public onlyOperator {
        require(_assetID > 0 && _assetID <= originalAssets.length, "invalid asset id");
        Asset storage oa = originalAssets[_assetID - 1];
        if (_tubeID == 0 || oa.tubeID == _tubeID) {
            if (oa.active == false) {
                oa.active = true;
                emit AssetActivated(_assetID, oa.tubeID);
            }
        } else {
            Asset storage sa = shadowAssets[_assetID][_tubeID];
            if (sa.asset != address(0) && sa.active == false) {
                sa.active = true;
                emit AssetActivated(_assetID, _tubeID);
            }
        }
    }

    function deactivateAsset(uint256 _assetID, uint256 _tubeID) public onlyOperator {
        require(_assetID > 0 && _assetID <= originalAssets.length, "invalid asset id");
        Asset storage oa = originalAssets[_assetID - 1];
        if (_tubeID == 0 || oa.tubeID == _tubeID) {
            if (oa.active == true) {
                oa.active = false;
                emit AssetDeactivated(_assetID, oa.tubeID);
            }
        } else {
            Asset storage sa = shadowAssets[_assetID][_tubeID];
            if (sa.asset != address(0) && sa.active == true) {
                sa.active = false;
                emit AssetDeactivated(_assetID, _tubeID);
            }
        }
    }

    function activateTube(uint256 _tubeID) public onlyOperator {
        if (bannedTubeIDs[_tubeID]) {
            bannedTubeIDs[_tubeID] = false;
            emit TubeDeactivated(_tubeID);
        }
    }

    function deactivateTube(uint256 _tubeID) public onlyOperator {
        if (!bannedTubeIDs[_tubeID]) {
            bannedTubeIDs[_tubeID] = true;
            emit TubeActivated(_tubeID);
        }
    }

    function grant(address _account) public onlyOwner {
        if (!operators[_account]) {
            operators[_account] = true;
            emit OperatorGranted(_account);
        }
    }

    function revoke(address _account) public onlyOwner {
        if (operators[_account]) {
            operators[_account] = false;
            emit OperatorRevoked(_account);
        }
    }
}
