pragma solidity ^0.5.17;

import "../../core/modules/Controlled.sol";
import "../../core/modules/Controller.sol";


contract DisputeManagerMockForRegistry is Controlled {
    event Slashed(uint256 collected);
    event Collected(bool collected);
    event Drafted(address[] addresses, uint256 length);

    constructor(Controller _controller) Controlled(_controller) public {}

    function assignTokens(address _guardian, uint256 _amount) external {
        _guardiansRegistry().assignTokens(_guardian, _amount);
    }

    function burnTokens(uint256 _amount) external {
        _guardiansRegistry().burnTokens(_amount);
    }

    function slashOrUnlock(address[] calldata _guardians, uint256[] calldata _lockedAmounts, bool[] calldata _rewardedGuardians) external {
        uint256 collectedTokens = _guardiansRegistry().slashOrUnlock(_getLastEnsuredTermId(), _guardians, _lockedAmounts, _rewardedGuardians);
        emit Slashed(collectedTokens);
    }

    function collect(address _guardian, uint256 _amount) external {
        bool collected = _guardiansRegistry().collectTokens(_guardian, _amount, _getLastEnsuredTermId());
        emit Collected(collected);
    }

    function draft(
        bytes32 _termRandomness,
        uint256 _disputeId,
        uint256 _selectedGuardians,
        uint256 _batchRequestedGuardians,
        uint64 _roundRequestedGuardians,
        uint16 _lockPct
    )
        external
    {
        uint256[7] memory draftParams = [
            uint256(_termRandomness),
            _disputeId,
            _getLastEnsuredTermId(),
            _selectedGuardians,
            _batchRequestedGuardians,
            _roundRequestedGuardians,
            _lockPct
        ];

        (address[] memory guardians, uint256 length) = _guardiansRegistry().draft(draftParams);
        emit Drafted(guardians, length);
    }
}
