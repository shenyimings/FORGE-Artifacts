// SPDX-License-Identifier: MIT

/*------------------------------------------------------------------------------------------
████████████████████████████████████████████████████████████████████████████████████████████
█─▄─▄─█▄─▄▄▀█─▄▄─█▄─▄▄─█▄─▄█─▄▄▄─██▀▄─██▄─▄█████▄─▄▄─█▄─▄█▄─▀█▄─▄██▀▄─██▄─▀█▄─▄█─▄▄▄─█▄─▄▄─█
███─████─▄─▄█─██─██─▄▄▄██─██─███▀██─▀─███─██▀████─▄████─███─█▄▀─███─▀─███─█▄▀─██─███▀██─▄█▀█
▀▀▄▄▄▀▀▄▄▀▄▄▀▄▄▄▄▀▄▄▄▀▀▀▄▄▄▀▄▄▄▄▄▀▄▄▀▄▄▀▄▄▄▄▄▀▀▀▄▄▄▀▀▀▄▄▄▀▄▄▄▀▀▄▄▀▄▄▀▄▄▀▄▄▄▀▀▄▄▀▄▄▄▄▄▀▄▄▄▄▄▀
-------------------------------------------------------------------------------------------*/

pragma solidity =0.6.12;

import "./libs/BEP20.sol";
import "./libs/TimeLock.sol";
import "./libs/ITropicalUniques.sol";
import "./libs/Operable.sol";

// TropicalToken with Governance.
contract TropicalToken is BEP20, TimeLock {

    // Maximum Supply
    uint256 public maximumSupply = 31000000e18;

    // Presale Hardcap(in DAIQUIRI)
    uint256 public presaleHardCapTokens = 8653846e17;

    constructor() public BEP20("Tropical Finance Token", "DAIQUIRI", 18) {
        setExcludedFromAntiWhale(address(0), true);
        setExcludedFromAntiBot(address(0), true);
        setMaxTransferAmountRate(1000);
    }

    // Transfer Tax, only applied till tokens sold from Presale aren't emitted in the platform.
    uint256 public transferTax = 0;

    // Tropical's Unique Addresses contract, excluded from antiwhale and antibot.
    ITropicalUniques public tropicalUniques;

    // Antiwhale system
    mapping(address => bool) private _excludedFromAntiWhale;
    uint16 public maxTransferAmountRate = 250; // in basis point, represents a % of total supply
    uint16 public MINIMUM_antiWhaleRate = 25; // The Minimum transfer amount(antiWhale rate) rate that can be set in basis points. Can't be changed!

    // Unique Addresses of Tropical Ecosystem, the Tropical Features(AutoCompounding Vault, ...), to be excluded from bonuses and fees.
    function setTropicalUniques(ITropicalUniques _tropicalUniques) public onlyOperator timeLock {
        tropicalUniques = _tropicalUniques;
    }

    function isUniqueAddress(address _address) public view returns (bool){
        return tropicalUniques.isUniqueAddress(_address);
    }

    /**
    * @dev Returns the address is excluded from antiWhale or not.
    */
    function isExcludedFromAntiWhale(address _account) public view returns (bool) {
        return _excludedFromAntiWhale[_account] && _account != address(0) || isUniqueAddress(_account);
    }
    
    /**
    * @dev Exclude or include an address from antiWhale.
    * Can only be called by the current operator.
    */
    function setExcludedFromAntiWhale(address _account, bool _excluded) public onlyOperator timeLock {
        _excludedFromAntiWhale[_account] = _excluded;
    }

    function maxTransferAmount() public view returns (uint256) {
        return totalSupply().mul(maxTransferAmountRate).div(10000);
    }

    function setMaxTransferAmountRate(uint16 _value) public onlyOperator timeLock {
        require(_value >= MINIMUM_antiWhaleRate, "TROPICAL::antiWhale: antiWhale rate cannot be this lower");
        maxTransferAmountRate = _value;
    }

    function setTransferTax(uint _value) public onlyOperator timeLock { // TransferTax, only applied while presale sold tokens < tokens emitted to prevent selling pressure
        require (_value <= 1000, "TROPICAL:transferTaxError, TransferTax cannot be higher than 10%"); // TransferTax in basis points(10000), can't ever be higher than 10%.
        transferTax = _value;
    }

    modifier antiWhale(address sender, address recipient, uint256 amount) {
        if (maxTransferAmount() > 0) {
            if (
                isExcludedFromAntiWhale(recipient) == false && isExcludedFromAntiWhale(sender) == false && !isUniqueAddress(sender) && !isUniqueAddress(recipient)
            ) {
                require(amount <= maxTransferAmount(), "TROPICAL::antiWhale: Transfer amount exceeds the maxTransferAmount");
            }
        }
        _;
    }
    // End of AntiWhale

    // Antibot system, applies to: addLiquidity, removeLiquidity, buying, selling, withdrawals. 
    // It prevents double transactions/interactions between sender/receiver during a timeframe.
    mapping(address => mapping(address => uint256)) private lastAction;
    mapping(address => bool) private excludedFromAntiBot;
    uint16 antiBotBlocksPassed = 2; // The minimum blocks passed
    uint16 MAX_AntiBotBlocksPassed = 50; // The maximum value allowed for blocks passed, cant't wait for eternity. Can't be changed!

    /**
    * @dev Returns the address is excluded from antiBot or not.
    */
    function isExcludedFromAntiBot(address _account) public view returns (bool) {
        return excludedFromAntiBot[_account] && _account != address(0) || isUniqueAddress(_account);
    }
    
    /**
    * @dev Exclude or include an address from antiBot.
    * Can only be called by the current operator.
    */
    function setExcludedFromAntiBot(address _account, bool _excluded) public onlyOperator timeLock {
        excludedFromAntiBot[_account] = _excluded;
    }

    function setAntiBotBlocksPassed(uint16 value) public onlyOperator timeLock {
        require(value <= MAX_AntiBotBlocksPassed, "TROPICAL::antiBot: blocks passed exceed maximum allowed");
        antiBotBlocksPassed = value;
    }

    modifier antiBot(address recipient, address sender) {
        require(isExcludedFromAntiBot(recipient) || block.number >= lastAction[recipient][sender].add(antiBotBlocksPassed), 
        "TROPICAL::antiBot: Please wait before making another Transaction");
        _;
    }
    // End of Antibot
    
    // Total(Circulating) Supply and Burnt
    function totalSupplyAndBurnt() public view returns (uint256) {
        return totalSupply().add(balanceOf(address(0)));
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner. TimeLocked(MintLock) while Presale Duration
    function mint(address _to, uint256 _amount) public onlyOwner mintLock {
        _mint(_to, _amount);
        _moveDelegates(address(0), _delegates[_to], _amount);
    }

    /// @dev overrides transfer function to meet tokenomics of TROPICAL
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override antiWhale(sender, recipient, amount) antiBot(recipient, sender) {
        if(transferTax > 0 && totalSupplyAndBurnt() < presaleHardCapTokens) {
            // Deflationary strategy to decrease selling pressure by presale buyers, transferTax% of amount will be burned.
            uint256 burnAmount = amount.mul(transferTax).div(10000);
            _burn(sender, burnAmount);
            amount = amount.sub(burnAmount);
        }
        super._transfer(sender, recipient, amount);
        lastAction[recipient][sender] = block.number;
    }

    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    /// @dev A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

      /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    
    // @notice An event thats emitted when operator is changed
    event OperatorTransferred(address indexed previousOperator, address indexed newOperator);

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegator The address to get delegatee for
     */
    function delegates(address delegator)
        external
        view
        returns (address)
    {
        return _delegates[delegator];
    }

   /**
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "TROPICAL::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "TROPICAL::delegateBySig: invalid nonce");
        require(now <= expiry, "TROPICAL::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
        external
        view
        returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "TROPICAL::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee)
        internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying TROPICALs (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        uint32 blockNumber = safe32(block.number, "TROPICAL::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}
