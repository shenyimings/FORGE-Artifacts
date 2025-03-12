pragma solidity ^0.5.17;

import "../../registry/ILockManager.sol";
import "../../registry/GuardiansRegistry.sol";


contract LockManagerMock is ILockManager {
    string private constant ERROR_INVALID_TOKEN = "LM_INVALID_TOKEN";
    string private constant ERROR_TOKEN_DEPOSIT_FAILED = "LM_TOKEN_DEPOSIT_FAILED";
    string private constant ERROR_TOKEN_APPROVAL_FAILED = "LM_TOKEN_APPROVAL_FAILED";

    bool internal canUnlockMock;
    GuardiansRegistry public guardiansRegistry;

    constructor(GuardiansRegistry _guardiansRegistry) public {
        guardiansRegistry = _guardiansRegistry;
    }

    function unlock(address _guardian, uint256 _amount) external {
        guardiansRegistry.unlockActivation(_guardian, address(this), _amount, false);
    }

    function lockActivation(address _guardian, uint256 _amount) external {
        guardiansRegistry.lockActivation(_guardian, address(this), _amount);
    }

    function activateAndLock(address _guardian, uint256 _amount) external {
        GuardiansRegistry registry = guardiansRegistry;
        IERC20 token = registry.guardiansToken();

        require(token.transferFrom(_guardian, address(this), _amount), ERROR_TOKEN_DEPOSIT_FAILED);
        require(token.approve(address(registry), _amount), ERROR_TOKEN_APPROVAL_FAILED);

        registry.stakeAndActivate(_guardian, _amount);
        registry.lockActivation(_guardian, address(this), _amount);
    }

    function mockCanUnlock(bool _canUnlock) external {
        canUnlockMock = _canUnlock;
    }

    function canUnlock(address /* _guardian */, uint256 /* _amount */) external view returns (bool) {
        return canUnlockMock;
    }
}
