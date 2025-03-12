
///////////////////////////////////////////////
// QANX STARTS HERE, OPENZEPPELIN CODE ABOVE //
///////////////////////////////////////////////

contract QANX is ERC20 {

    // EVENTS TO BE EMITTED UPON LOCKS ARE APPLIED & REMOVED
    event LockApplied(address indexed account, uint256 amount, uint32 hardLockUntil, uint32 softLockUntil, uint8 allowedHops);
    event LockRemoved(address indexed account);

    // INITIALIZE AN ERC20 TOKEN BASED ON THE OPENZEPPELIN VERSION
    constructor() ERC20("QANX Token", "QANX") {

        // INITIALLY MINT TOTAL SUPPLY TO CREATOR
        _mint(_msgSender(), 3333333000 * (10 ** 18));
    }

    // MAPPING FOR QUANTUM PUBLIC KEY HASHES
    mapping (address => bytes32) private _qPubKeyHashes;

    // REGISTER QUANTUM PUBLIC KEY HASH OF THE CURRENT ACCOUNT
    function setQuantumPubkeyHash(bytes32 qPubKeyHash) external {
        _qPubKeyHashes[_msgSender()] = qPubKeyHash;
    }

    // QUERY A QUANTUM PUBLIC KEY HASH OF A GIVEN ACCOUNT
    function getQuantumPubkeyHash(address account) external view virtual returns (bytes32) {
        return _qPubKeyHashes[account];
    }

    // REPRESENTS A LOCK WHICH MIGHT BE APPLIED ON AN ADDRESS
    struct Lock {
        uint256 tokenAmount;    // HOW MANY TOKENS ARE LOCKED
        uint32 hardLockUntil;   // UNTIL WHEN NO LOCKED TOKENS CAN BE ACCESSED
        uint32 softLockUntil;   // UNTIL WHEN LOCKED TOKENS CAN BE GRADUALLY RELEASED
        uint8 allowedHops;      // HOW MANY TRANSFERS LEFT WITH SAME LOCK PARAMS
        uint32 lastUnlock;      // LAST GRADUAL UNLOCK TIME (SOFTLOCK PERIOD)
        uint256 unlockPerSec;   // HOW MANY TOKENS ARE UNLOCKABLE EACH SEC FROM HL -> SL
    }

    // THIS MAPS LOCK PARAMS TO CERTAIN ADDRESSES WHICH RECEIVED LOCKED TOKENS
    mapping (address => Lock) private _locks;

    // RETURNS LOCK INFORMATION OF A GIVEN ADDRESS
    function lockOf(address account) external view virtual returns (Lock memory) {
        return _locks[account];
    }

    // RETURN THE BALANCE OF UNLOCKED AND LOCKED TOKENS COMBINED
    function balanceOf(address account) external view virtual override returns (uint256) {
        return _balances[account] + _locks[account].tokenAmount;
    }

    // TRANSFER FUNCTION WITH LOCK PARAMETERS
    function transferLocked(address recipient, uint256 amount, uint32 hardLockUntil, uint32 softLockUntil, uint8 allowedHops) external returns (bool) {

        // ONLY ONE LOCKED TRANSACTION ALLOWED PER RECIPIENT
        require(_locks[recipient].tokenAmount == 0, "Only one lock per address allowed!");

        // SENDER MUST HAVE ENOUGH TOKENS (UNLOCKED + LOCKED BALANCE COMBINED)
        require(_balances[_msgSender()] + _locks[_msgSender()].tokenAmount >= amount, "Transfer amount exceeds balance");

        // IF SENDER HAS ENOUGH UNLOCKED BALANCE, THEN LOCK PARAMS CAN BE CHOSEN
        if(_balances[_msgSender()] >= amount){

            // DEDUCT SENDER BALANCE
            _balances[_msgSender()] = _balances[_msgSender()] - amount;

            // APPLY LOCK
            return _applyLock(recipient, amount, hardLockUntil, softLockUntil, allowedHops);
        }

        // OTHERWISE REQUIRE THAT THE CHOSEN LOCK PARAMS ARE SAME / STRICTER (allowedHops) THAN THE SENDER'S
        require(
            hardLockUntil >= _locks[_msgSender()].hardLockUntil && 
            softLockUntil >= _locks[_msgSender()].softLockUntil && 
            allowedHops < _locks[_msgSender()].allowedHops
        );

        // IF SENDER HAS ENOUGH LOCKED BALANCE
        if(_locks[_msgSender()].tokenAmount >= amount){

            // DECREASE LOCKED BALANCE OF SENDER
            _locks[_msgSender()].tokenAmount = _locks[_msgSender()].tokenAmount - amount;

            // APPLY LOCK
            return _applyLock(recipient, amount, hardLockUntil, softLockUntil, allowedHops);
        }

        // IF NO CONDITIONS WERE MET SO FAR, DEDUCT FROM THE UNLOCKED BALANCE
        _balances[_msgSender()] = _balances[_msgSender()] - (amount - _locks[_msgSender()].tokenAmount);

        // THEN SPEND LOCKED BALANCE OF SENDER FIRST
        _locks[_msgSender()].tokenAmount = 0;

        // APPLY LOCK
        return _applyLock(recipient, amount, hardLockUntil, softLockUntil, allowedHops);
    }

    // APPLIES LOCK TO RECIPIENT WITH SPECIFIED PARAMS AND EMITS A TRANSFER EVENT
    function _applyLock(address recipient, uint256 amount, uint32 hardLockUntil, uint32 softLockUntil, uint8 allowedHops) private returns (bool) {

        // MAKE SURE THAT SOFTLOCK IS AFTER HARDLOCK
        require(softLockUntil > hardLockUntil, "SoftLock must be greater than HardLock!");

        // APPLY LOCK, EMIT TRANSFER EVENT
        _locks[recipient] = Lock(amount, hardLockUntil, softLockUntil, allowedHops, hardLockUntil, amount / (softLockUntil - hardLockUntil));
        emit LockApplied(recipient, amount, hardLockUntil, softLockUntil, allowedHops);
        emit Transfer(_msgSender(), recipient, amount);
        return true;
    }

    function lockedBalanceOf(address account) external view virtual returns (uint256) {
        return _locks[account].tokenAmount;
    }

    function unlockedBalanceOf(address account) external view virtual returns (uint256) {
        return _balances[account];
    }

    function unlockableBalanceOf(address account) public view virtual returns (uint256) {

        // IF THE HARDLOCK HAS NOT PASSED YET, THERE ARE NO UNLOCKABLE TOKENS
        if(block.timestamp < _locks[account].hardLockUntil) {
            return 0;
        }

        // IF THE SOFTLOCK PERIOD PASSED, ALL CURRENTLY TOKENS ARE UNLOCKABLE
        if(block.timestamp > _locks[account].softLockUntil) {
            return _locks[account].tokenAmount;
        }

        // OTHERWISE THE PROPORTIONAL AMOUNT IS UNLOCKABLE
        return (block.timestamp - _locks[account].lastUnlock) * _locks[account].unlockPerSec;
    }

    function unlock(address account) external returns (bool) {

        // CALCULATE UNLOCKABLE BALANCE
        uint256 unlockable = unlockableBalanceOf(account);

        // ONLY ADDRESSES OWNING LOCKED TOKENS AND BYPASSED HARDLOCK TIME ARE UNLOCKABLE
        require(unlockable > 0 && _locks[account].tokenAmount > 0 && block.timestamp > _locks[account].hardLockUntil, "No unlockable tokens!");

        // SET LAST UNLOCK TIME, DEDUCT FROM LOCKED BALANCE & CREDIT TO REGULAR BALANCE
        _locks[account].lastUnlock = uint32(block.timestamp);
        _locks[account].tokenAmount = _locks[account].tokenAmount - unlockable;
        _balances[account] = _balances[account] + unlockable;

        // IF NO MORE LOCKED TOKENS LEFT, REMOVE LOCK OBJECT FROM ADDRESS
        if(_locks[account].tokenAmount == 0){
            delete _locks[account];
            emit LockRemoved(account);
        }

        // UNLOCK SUCCESSFUL
        emit Transfer(account, account, unlockable);
        return true;
    }
}
