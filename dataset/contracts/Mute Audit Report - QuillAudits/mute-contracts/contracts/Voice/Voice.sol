// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../Utils/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

/**
 * @title Mute Voice ERC20 token
 * @dev DAO for the MUTE Ecosystem on the Ethereum Protocol.
 *
 *      Each transaction that is not sent from the mapping of nonTaxedAddresses (initially owner and WETH/VOICE uniswap pair)
 *      will be taxed at a rate of 1% paid out in VOICE to the taxReceiveAddress.
 *
 */
contract Voice is Initializable, ContextUpgradeSafe, OwnableUpgradeSafe {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 private constant INITIAL_SUPPLY =  60 * 10**3 * 10**18;

    /// @notice 1% (1/100) tax for every transaction
    uint16 public TAX_FRACTION;
    address public taxReceiveAddress;

    bool public isTaxEnabled;
    mapping(address => bool) public nonTaxedAddresses;


    mapping (address => address) internal _delegates;

    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    mapping (address => uint32) public numCheckpoints;

    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping (address => uint) public nonces;

    uint256 public vaultThreshold;

    address public _dao;

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    receive() external payable {}

    modifier onlyDAO() {
        require(owner() == _msgSender() || _dao == _msgSender(), "Voice::onlyDAO: caller is not the dao");
        _;
    }

    function initialize() public initializer {
        require(owner() == address(0), "Voice::Initialize: Contract has already been initialized");

        _name = "Voice Token";
        _symbol = "VOICE";
        _decimals = 18;
        __Context_init_unchained();
        __Ownable_init_unchained();
        isTaxEnabled = false;
        TAX_FRACTION = 100; // 100 / 10000 = 1%

        _balances[msg.sender] = _balances[msg.sender].add(INITIAL_SUPPLY);
        _totalSupply = _totalSupply.add(INITIAL_SUPPLY);
        emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);

        vaultThreshold = 500 * 10 ** 18;

        nonTaxedAddresses[_msgSender()] = true;
    }

    function setTaxReceiveAddress(address _taxReceiveAddress) external onlyDAO {
        taxReceiveAddress = _taxReceiveAddress;
    }

    function setAddressTax(address _address, bool ignoreTax) external onlyDAO {
        nonTaxedAddresses[_address] = ignoreTax;
    }

    function setTaxFraction(uint16 _tax_fraction) external onlyDAO {
        TAX_FRACTION = _tax_fraction;
    }

    function setVaultThreshold(uint256 _vaultThreshold) external onlyDAO {
        vaultThreshold = _vaultThreshold;
    }

    function setDAO(address dao) external onlyOwner {
        _dao = dao;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view  returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        //do not tax whitelisted addresses
        //do not tax if tax is disabled
        if(nonTaxedAddresses[sender] == true || TAX_FRACTION == 0 || balanceOf(taxReceiveAddress) > vaultThreshold){
          _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");

          if(balanceOf(taxReceiveAddress) > vaultThreshold){
              IMuteVault(taxReceiveAddress).reward();
          }

          _balances[recipient] = _balances[recipient].add(amount);

          _moveDelegates(_delegates[sender], _delegates[recipient], amount);

          emit Transfer(sender, recipient, amount);
          return;
        }

        uint256 feeAmount = amount.mul(TAX_FRACTION).div(10000);

        uint256 newAmount = amount.sub(feeAmount);

        require(amount == feeAmount.add(newAmount), "Voice: math is broken");

        _balances[sender] = _balances[sender].sub(amount, "Voice: transfer amount exceeds balance");
        // send amount minus the 1% fee
        _balances[recipient] = _balances[recipient].add(newAmount);
        // 1% Voice fee to taxReceiveAddress
        _balances[taxReceiveAddress] = _balances[taxReceiveAddress].add(feeAmount);

        _moveDelegates(_delegates[sender], _delegates[recipient], newAmount);
        _moveDelegates(_delegates[sender], _delegates[taxReceiveAddress], feeAmount);

        emit Transfer(sender, recipient, newAmount);
        emit Transfer(sender, taxReceiveAddress, feeAmount);
    }


    function Burn(uint256 amount) external returns (bool) {
        require(msg.sender != address(0), "ERC20: burn from the zero address");

        _moveDelegates(_delegates[msg.sender], address(0), amount);

        _balances[msg.sender] = _balances[msg.sender].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(msg.sender, address(0), amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function delegates(address delegator) external view returns (address) {
        return _delegates[delegator];
    }

    function getCurrentVotes(address account) external view returns (uint256) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    function getPriorVotes(address account, uint blockNumber) external view returns (uint256) {
        require(blockNumber < block.number, "Gov::getPriorVotes: not yet determined");

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

     function delegate(address delegatee) external {
         return _delegate(msg.sender, delegatee);
     }

     function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) external {
         bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), getChainId(), address(this)));
         bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
         bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
         address signatory = ecrecover(digest, v, r, s);
         require(signatory != address(0), "Gov::delegateBySig: invalid signature");
         require(nonce == nonces[signatory]++, "Gov::delegateBySig: invalid nonce");
         require(now <= expiry, "Gov::delegateBySig: signature expired");
         return _delegate(signatory, delegatee);
     }

     function _delegate(address delegator, address delegatee) internal {
         address currentDelegate = _delegates[delegator];
         uint256 delegatorBalance = balanceOf(delegator);
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

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        uint32 blockNumber = safe32(block.number, "Gov::_writeCheckpoint: block number exceeds 32 bits");

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

interface IMuteVault {
    function reward() external returns (bool);
}
