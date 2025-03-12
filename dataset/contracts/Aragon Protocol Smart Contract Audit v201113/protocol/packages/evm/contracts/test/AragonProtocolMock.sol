pragma solidity ^0.5.17;

import "../AragonProtocol.sol";
import "./lib/TimeHelpersMock.sol";


contract AragonProtocolMock is AragonProtocol, TimeHelpersMock {
    uint64 internal mockedTermId;
    bytes32 internal mockedTermRandomness;

    constructor(
        uint64[2] memory _termParams,
        address[3] memory _governors,
        IERC20 _feeToken,
        uint256[3] memory _fees,
        uint64[5] memory _roundStateDurations,
        uint16[2] memory _pcts,
        uint64[4] memory _roundParams,
        uint256[2] memory _appealCollateralParams,
        uint256 _minActiveBalance
    )
        AragonProtocol(
            _termParams,
            _governors,
            _feeToken,
            _fees,
            _roundStateDurations,
            _pcts,
            _roundParams,
            _appealCollateralParams,
            _minActiveBalance
        )
        public
    {}

    function setDisputeManagerMock(address _addr) external {
        // This function allows setting any address (including EOAs) as the DisputeManager module in this controller
        currentModules[MODULE_ID_DISPUTE_MANAGER] = _addr;
        allModules[_addr].id = MODULE_ID_DISPUTE_MANAGER;
        emit ModuleSet(MODULE_ID_DISPUTE_MANAGER, _addr);
    }

    function setDisputeManager(address _addr) external {
        _setModule(MODULE_ID_DISPUTE_MANAGER, _addr);
        _linkNewModule(MODULE_ID_DISPUTE_MANAGER, _addr);
    }

    function setGuardiansRegistry(address _addr) external {
        _setModule(MODULE_ID_GUARDIANS_REGISTRY, _addr);
        _linkNewModule(MODULE_ID_GUARDIANS_REGISTRY, _addr);
    }

    function setVoting(address _addr) external {
        _setModule(MODULE_ID_VOTING, _addr);
        _linkNewModule(MODULE_ID_VOTING, _addr);
    }

    function setPaymentsBook(address _addr) external {
        _setModule(MODULE_ID_PAYMENTS_BOOK, _addr);
        _linkNewModule(MODULE_ID_PAYMENTS_BOOK, _addr);
    }

    function setTreasury(address _addr) external {
        _setModule(MODULE_ID_TREASURY, _addr);
        _linkNewModule(MODULE_ID_TREASURY, _addr);
    }

    function _linkNewModule(bytes32 _id, address _addr) private {
        (bytes32[] memory knownIds, address[] memory knownAddresses) = _knownModules();
        // Update the new module's link with the already known modules
        _syncModuleLinks(_toArray(_addr), knownIds);
        // Update the already known modules' links with the new module
        _syncModuleLinks(knownAddresses, _toArray(_id));
    }

    function mockIncreaseTerm() external {
        if (mockedTermId != 0) mockedTermId = mockedTermId + 1;
        else mockedTermId = _lastEnsuredTermId() + 1;
    }

    function mockIncreaseTerms(uint64 _terms) external {
        if (mockedTermId != 0) mockedTermId = mockedTermId + _terms;
        else mockedTermId = _lastEnsuredTermId() + _terms;
    }

    function mockSetTerm(uint64 _termId) external {
        mockedTermId = _termId;
    }

    function mockSetTermRandomness(bytes32 _termRandomness) external {
        mockedTermRandomness = _termRandomness;
    }

    function ensureCurrentTerm() external returns (uint64) {
        if (mockedTermId != 0) return mockedTermId;
        return super._ensureCurrentTerm();
    }

    function getCurrentTermId() external view returns (uint64) {
        if (mockedTermId != 0) return mockedTermId;
        return super._currentTermId();
    }

    function getLastEnsuredTermId() external view returns (uint64) {
        if (mockedTermId != 0) return mockedTermId;
        return super._lastEnsuredTermId();
    }

    function getTermRandomness(uint64 _termId) external view returns (bytes32) {
        if (mockedTermRandomness != bytes32(0)) return mockedTermRandomness;
        return super._computeTermRandomness(_termId);
    }

    function _computeTermRandomness(uint64 _termId) internal view returns (bytes32) {
        if (mockedTermRandomness != bytes32(0)) return mockedTermRandomness;
        return super._computeTermRandomness(_termId);
    }

    function _knownModules() internal view returns (bytes32[] memory ids, address[] memory addresses) {
        ids = new bytes32[](5);
        ids[0] = MODULE_ID_DISPUTE_MANAGER;
        ids[1] = MODULE_ID_GUARDIANS_REGISTRY;
        ids[2] = MODULE_ID_VOTING;
        ids[3] = MODULE_ID_PAYMENTS_BOOK;
        ids[4] = MODULE_ID_TREASURY;

        addresses = new address[](5);
        for (uint i = 0; i < ids.length; i++) {
            addresses[i] = currentModules[ids[i]];
        }
    }

    function _toArray(address _addr) private pure returns (address[] memory addresses) {
        addresses = new address[](1);
        addresses[0] = _addr;
    }

    function _toArray(bytes32 _word) private pure returns (bytes32[] memory words) {
        words = new bytes32[](1);
        words[0] = _word;
    }
}
