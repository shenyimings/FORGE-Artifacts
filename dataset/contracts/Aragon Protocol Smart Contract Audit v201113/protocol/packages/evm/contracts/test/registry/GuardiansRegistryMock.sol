pragma solidity ^0.5.17;

import "../../registry/GuardiansRegistry.sol";


contract GuardiansRegistryMock is GuardiansRegistry {
    string private constant ERROR_INVALID_MOCK_LOCK_AMOUNT = 'GR_INVALID_MOCK_LOCK_AMOUNT';

    bool internal nextDraftMocked;
    address[] internal mockedSelectedGuardians;

    constructor (Controller _controller, IERC20 _guardianToken, uint256 _totalActiveBalanceLimit)
        public
        GuardiansRegistry(_controller, _guardianToken, _totalActiveBalanceLimit)
    {}

    function mockLock(address _guardian, uint256 _leftUnlockedAmount) external {
        Guardian storage guardian = guardiansByAddress[_guardian];
        uint256 active = _existsGuardian(guardian) ? tree.getItem(guardian.id) : 0;
        require(_leftUnlockedAmount < active, ERROR_INVALID_MOCK_LOCK_AMOUNT);
        guardian.lockedBalance = active - _leftUnlockedAmount;
    }

    function collect(address _guardian, uint256 _amount) external {
        Guardian storage guardian = guardiansByAddress[_guardian];
        uint64 nextTermId = _getLastEnsuredTermId() + 1;
        tree.update(guardian.id, nextTermId, _amount, false);
    }

    function mockNextDraft(address[] calldata _selectedGuardians, uint256[] calldata _weights) external {
        nextDraftMocked = true;

        delete mockedSelectedGuardians;
        for (uint256 i = 0; i < _selectedGuardians.length; i++) {
            for (uint256 j = 0; j < _weights[i]; j++) {
                mockedSelectedGuardians.push(_selectedGuardians[i]);
            }
        }
    }

    function _treeSearch(DraftParams memory _params) internal view returns (uint256[] memory, uint256[] memory) {
        if (nextDraftMocked) {
            return _runMockedSearch(_params);
        }
        return super._treeSearch(_params);
    }

    function _runMockedSearch(DraftParams memory _params) internal view returns (uint256[] memory ids, uint256[] memory activeBalances) {
        uint256 length = mockedSelectedGuardians.length;
        ids = new uint256[](length);
        activeBalances = new uint256[](length);

        for (uint256 i = 0; i < mockedSelectedGuardians.length; i++) {
            address guardian = mockedSelectedGuardians[i];
            uint256 id = guardiansByAddress[guardian].id;
            uint256 activeBalance = tree.getItemAt(id, _params.termId);

            ids[i] = id;
            activeBalances[i] = activeBalance;
        }
    }
}
