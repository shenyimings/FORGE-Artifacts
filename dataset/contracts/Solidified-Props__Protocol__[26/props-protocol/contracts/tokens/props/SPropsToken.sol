// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./ISPropsToken.sol";

/**
 * @title  SPropsToken
 * @author Forked from: Compound
 *         Changes by: Props
 * @notice The governance token in the Props protocol.
 * @dev    sProps tokens represent Props stake shares (each sProps token
 *         corresponds to a staked Props token). sProps are not transferrable,
 *         only mintable and burnable. Minting and burning are actions
 *         restricted to the controller of the contract.
 *         Changes to the original Compound contract:
 *         - the contract is ownable and upgradeable
 *         - transfer-related actions are forbidden (the contract simply
 *           reverts on transferring or approving)
 *         - mint and burn functions were added
 */
contract SPropsToken is Initializable, IERC20Upgradeable, ISPropsToken {
    using SafeMathUpgradeable for uint256;

    /**************************************
                     FIELDS
    ***************************************/

    // The sProps token controller
    address public controller;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    // Allowance amounts on behalf of others
    mapping(address => mapping(address => uint96)) internal _allowances;

    // Official record of token balances for each account
    mapping(address => uint96) internal _balances;

    // A record of each accounts delegate
    mapping(address => address) public delegates;

    // A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    // A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    // The number of checkpoints for each account
    mapping(address => uint32) public numCheckpoints;

    // The EIP-712 typehash for the contract's domain
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_TYPEHASH;

    // The EIP-712 typehash for the delegation struct used by the contract
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DELEGATION_TYPEHASH;

    // A record of states for signing / validating signatures
    mapping(address => uint256) public nonces;

    /**************************************
                     EVENTS
    ***************************************/

    // An event thats emitted when an account changes its delegate
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    // An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    /**************************************
                    MODIFIERS
    ***************************************/

    modifier only(address _account) {
        require(msg.sender == _account, "Unauthorized");
        _;
    }

    /***************************************
                   INITIALIZER
    ****************************************/

    function initialize(address _controller) public initializer {
        controller = _controller;

        _name = "sProps";
        _symbol = "sProps";
        _decimals = 18;
        _totalSupply = 0;

        DOMAIN_TYPEHASH = // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;
        DELEGATION_TYPEHASH = // keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)")
        0xe48329057bfd03d55e49b547132e39cffd9c1820ad7b9d4c5307691425d15adf;
    }

    /***************************************
                CONTROLLER ACTIONS
    ****************************************/

    /**
     * @dev Mint new tokens.
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to be minted
     */
    function mint(address dst, uint256 rawAmount) external override only(controller) {
        require(dst != address(0), "Cannot mint to the zero address");

        // Mint the amount
        uint96 amount = safe96(rawAmount);
        _totalSupply = safe96(_totalSupply.add(amount));

        // Transfer the amount to the destination account
        _balances[dst] = add96(_balances[dst], amount);
        emit Transfer(address(0), dst, amount);

        // Move delegates
        _moveDelegates(address(0), delegates[dst], amount);
    }

    /**
     * @dev Burn existing tokens.
     * @param src The address of the source account
     * @param rawAmount The number of tokens to be burned
     */
    function burn(address src, uint256 rawAmount) external override only(controller) {
        require(src != address(0), "Cannot burn from the zero address");

        // Burn the amount
        uint96 amount = safe96(rawAmount);
        _totalSupply = safe96(_totalSupply.sub(amount));

        // Transfer the amount from the source account
        _balances[src] = sub96(_balances[src], amount);
        emit Transfer(src, address(0), amount);

        // Move delegates
        _moveDelegates(delegates[src], address(0), amount);
    }

    /***************************************
                  ERC20 ACTIONS
    ****************************************/

    /**
     * @dev EIP-20 token name for this token.
     */
    function name() external view returns (string memory) {
        return _name;
    }

    /**
     * @dev EIP-20 token symbol for this token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev EIP-20 token decimals for this token.
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev EIP-20 total token supply for this token.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Get the number of tokens held by the `account`.
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Get the number of tokens `spender` is approved to spend on behalf of `account`.
     * @param account The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address account, address spender) external view override returns (uint256) {
        return _allowances[account][spender];
    }

    /**
     * @dev sProps are not transferrable, so here we simply revert.
     */
    function approve(address, uint256) external pure override returns (bool) {
        revert("sProps are not transferrable");
    }

    /**
     * @dev sProps are not transferrable, so here we simply revert.
     */
    function transfer(address, uint256) external pure override returns (bool) {
        revert("sProps are not transferrable");
    }

    /**
     * @dev sProps are not transferrable, so here we simply revert.
     */
    function transferFrom(
        address,
        address,
        uint256
    ) external pure override returns (bool) {
        revert("sProps are not transferrable");
    }

    /***************************************
               DELEGATION ACTIONS
    ****************************************/

    /**
     * @dev Delegate votes from `msg.sender` to `delegatee`.
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) external override {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @dev Delegates votes from signatory to `delegatee`.
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        bytes32 domainSeparator =
            keccak256(
                abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(_name)), getChainId(), address(this))
            );
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Invalid signature");
        require(nonce == nonces[signatory]++, "Invalid nonce");
        require(block.timestamp <= expiry, "Signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @dev Gets the current votes balance for `account`.
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view override returns (uint96) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @dev Determine the prior number of votes for an account as of a block number.
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        override
        returns (uint96)
    {
        require(blockNumber < block.number, "Not yet determined");

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
            // Ceil, avoiding overflow
            uint32 center = upper - (upper - lower) / 2;
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

    /***************************************
                     HELPERS
    ****************************************/

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint96 delegatorBalance = _balances[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint96 amount
    ) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint96 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint96 srcRepNew = sub96(srcRepOld, amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint96 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint96 dstRepNew = add96(dstRepOld, amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint96 oldVotes,
        uint96 newVotes
    ) internal {
        uint32 blockNumber = safe32(block.number);

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint256 n) internal pure returns (uint32) {
        require(n < 2**32);
        return uint32(n);
    }

    function safe96(uint256 n) internal pure returns (uint96) {
        require(n < 2**96);
        return uint96(n);
    }

    function add96(uint96 a, uint96 b) internal pure returns (uint96) {
        uint96 c = a + b;
        require(c >= a);
        return c;
    }

    function sub96(uint96 a, uint96 b) internal pure returns (uint96) {
        require(b <= a);
        return a - b;
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
