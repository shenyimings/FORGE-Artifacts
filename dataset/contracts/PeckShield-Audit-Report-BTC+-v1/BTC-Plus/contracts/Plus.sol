// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IPlus.sol";

/**
 * @title Plus token base contract.
 *
 * Plus token is a value pegged ERC20 token which provides global interest to all holders.
 * It can be categorized as single plus token and composite plus token:
 * 
 * Single plus token is backed by one ERC20 token and targeted at yield generation.
 * Composite plus token is backed by a basket of ERC20 token and targeted at better basket management.
 */
abstract contract Plus is ERC20Upgradeable, IPlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Emitted each time the share of a user is updated.
     */
    event UserShareUpdated(address indexed account, uint256 oldShare, uint256 newShare, uint256 totalShares);
    event Rebased(uint256 oldIndex, uint256 newIndex, uint256 totalUnderlying);
    event Donated(address indexed account, uint256 amount, uint256 share);

    event GovernanceUpdated(address indexed oldGovernance, address indexed newGovernance);
    event StrategistUpdated(address indexed strategist, bool allowed);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event RedeemFeeUpdated(uint256 oldFee, uint256 newFee);
    event MintPausedUpdated(address indexed token, bool paused);

    uint256 public constant MAX_PERCENT = 10000; // 0.01%
    uint256 public constant WAD = 1e18;

    /**
     * @dev Struct to represent a rebase hook.
     */
    struct Transaction {
        bool enabled;
        address destination;
        bytes data;
    }
    // Rebase hooks
    Transaction[] public transactions;

    uint256 public totalShares;
    mapping(address => uint256) public userShare;
    // The exchange rate between total shares and BTC+ total supply. Express in WAD.
    // It's equal to the amount of plus token per share.
    // Note: The index will never decrease!
    uint256 public index;

    address public override governance;
    mapping(address => bool) public override strategists;
    address public override treasury;

    // Governance parameters
    uint256 public redeemFee;

    // EIP 2612: Permit
    // Credit: https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;

    /**
     * @dev Initializes the plus token contract.
     */
    function __PlusToken__init(string memory _name, string memory _symbol) internal initializer {
        __ERC20_init(_name, _symbol);
        index = WAD;
        governance = msg.sender;
        treasury = msg.sender;

        uint _chainId;
        assembly {
            _chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(_name)),
                keccak256(bytes('1')),
                _chainId,
                address(this)
            )
        );
    }

    function _checkGovernance() internal view {
        require(msg.sender == governance, "not governance");
    }

    modifier onlyGovernance() {
        _checkGovernance();
        _;
    }

    function _checkStrategist() internal view {
        require(msg.sender == governance || strategists[msg.sender], "not strategist");
    }

    modifier onlyStrategist {
        _checkStrategist();
        _;
    }

    /**
     * @dev Returns the total value of the plus token in terms of the peg value in WAD.
     * All underlying token amounts have been scaled to 18 decimals, then expressed in WAD.
     */
    function _totalUnderlyingInWad() internal view virtual returns (uint256);

    /**
     * @dev Returns the total value of the plus token in terms of the peg value.
     * For single plus, it's equal to its total supply.
     * For composite plus, it's equal to the total amount of single plus tokens in its basket.
     */
    function totalUnderlying() external view override returns (uint256) {
        return _totalUnderlyingInWad().div(WAD);
    }

    /**
     * @dev Returns the total supply of plus token. See {IERC20Updateable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return totalShares.mul(index).div(WAD);
    }

    /**
     * @dev Returns the balance of plus token for the account. See {IERC20Updateable-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return userShare[account].mul(index).div(WAD);
    }

    /**
     * @dev Returns the current liquidity ratio of the plus token in WAD.
     */
    function liquidityRatio() public view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        return _totalSupply == 0 ? WAD : _totalUnderlyingInWad().div(_totalSupply);
    }

    /**
     * @dev Accrues interest to increase index.
     */
    function rebase() public override {
        uint256 _totalShares = totalShares;
        if (_totalShares == 0)  return;

        // underlying is in WAD, and index is also in WAD
        uint256 _underlying = _totalUnderlyingInWad();
        uint256 _oldIndex = index;
        uint256 _newIndex = _underlying.div(_totalShares);

        // _newIndex - oldIndex is the amount of interest generated for each share
        // _oldIndex might be larger than _newIndex in a short period of time. In this period, the liquidity ratio is smaller than 1.
        if (_newIndex > _oldIndex) {
            // Index can never decrease
            index = _newIndex;

            for (uint256 i = 0; i < transactions.length; i++) {
                Transaction storage transaction = transactions[i];
                if (transaction.enabled) {
                    (bool success, ) = transaction.destination.call(transaction.data);
                    require(success, "rebase hook failed");
                }
            }
            
            // In this event we are returning underlyiing() which can be used to compute the actual interest generated.
            emit Rebased(_oldIndex, _newIndex, _underlying.div(WAD));
        }
    }

    /**
     * @dev Allows anyone to donate their plus asset to all other holders.
     * @param _amount Amount of plus token to donate.
     */
    function donate(uint256 _amount) public override {
        // Rebase first to make index up-to-date
        rebase();
        // Special handling of -1 is required here in order to fully donate all shares, since interest
        // will be accrued between the donate transaction is signed and mined.
        uint256 _share;
        if (_amount == uint256(int256(-1))) {
            _share = userShare[msg.sender];
            _amount = _share.mul(index).div(WAD);
        } else {
            _share  = _amount.mul(WAD).div(index);
        }

        uint256 _oldShare = userShare[msg.sender];
        uint256 _newShare = _oldShare.sub(_share, "insufficient share");
        uint256 _newTotalShares = totalShares.sub(_share);
        userShare[msg.sender] = _newShare;
        totalShares = _newTotalShares;

        emit UserShareUpdated(msg.sender, _oldShare, _newShare, _newTotalShares);
        emit Donated(msg.sender, _amount, _share);
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        require(_sender != _recipient, "recipient cannot be sender");
        // Rebase first to make index up-to-date
        rebase();
        uint256 _shareToTransfer = _amount.mul(WAD).div(index);

        uint256 _oldSenderShare = userShare[_sender];
        uint256 _newSenderShare = _oldSenderShare.sub(_shareToTransfer, "insufficient share");
        uint256 _oldRecipientShare = userShare[_recipient];
        uint256 _newRecipientShare = _oldRecipientShare.add(_shareToTransfer);
        uint256 _totalShares = totalShares;

        userShare[_sender] = _newSenderShare;
        userShare[_recipient] = _newRecipientShare;

        emit UserShareUpdated(_sender, _oldSenderShare, _newSenderShare, _totalShares);
        emit UserShareUpdated(_recipient, _oldRecipientShare, _newRecipientShare, _totalShares);
    }

    /**
     * @dev Gassless approve.
     */
    function permit(address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) external {
        require(_deadline >= block.timestamp, 'expired');
        bytes32 _digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, nonces[_owner]++, _deadline))
            )
        );
        address _recoveredAddress = ecrecover(_digest, _v, _r, _s);
        require(_recoveredAddress != address(0) && _recoveredAddress == _owner, 'invalid signature');
        _approve(_owner, _spender, _value);
    }

    /*********************************************
     *
     *    Governance methods
     *
     **********************************************/

    /**
     * @dev Updates governance. Only governance can update governance.
     */
    function setGovernance(address _governance) external onlyGovernance {
        address _oldGovernance = governance;
        governance = _governance;
        emit GovernanceUpdated(_oldGovernance, _governance);
    }

    /**
     * @dev Updates strategist. Both governance and strategists can update strategist.
     */
    function setStrategist(address _strategist, bool _allowed) external onlyStrategist {
        require(_strategist != address(0x0), "strategist not set");

        strategists[_strategist] = _allowed;
        emit StrategistUpdated(_strategist, _allowed);
    }

    /**
     * @dev Updates the treasury. Only governance can update treasury.
     */
    function setTreasury(address _treasury) external onlyGovernance {
        require(_treasury != address(0x0), "treasury not set");

        address _oldTreasury = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(_oldTreasury, _treasury);
    }

    /**
     * @dev Updates the redeem fee. Only governance can update redeem fee.
     */
    function setRedeemFee(uint256 _redeemFee) external onlyGovernance {
        require(_redeemFee <= MAX_PERCENT, "redeem fee too big");
        uint256 _oldFee = redeemFee;

        redeemFee = _redeemFee;
        emit RedeemFeeUpdated(_oldFee, _redeemFee);
    }

    /**
     * @dev Used to salvage any ETH deposited to BTC+ contract by mistake. Only strategist can salvage ETH.
     * The salvaged ETH is transferred to treasury for futher operation.
     */
    function salvage() external onlyStrategist {
        uint256 _amount = address(this).balance;
        address payable _target = payable(treasury);
        (bool _success, ) = _target.call{value: _amount}(new bytes(0));
        require(_success, 'ETH salvage failed');
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken().
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual returns (bool);

    /**
     * @dev Used to salvage any token deposited to plus contract by mistake. Only strategist can salvage token.
     * The salvaged token is transferred to treasury for futhuer operation.
     * @param _token Address of the token to salvage.
     */
    function salvageToken(address _token) external onlyStrategist {
        require(_token != address(0x0), "token not set");
        require(_salvageable(_token), "cannot salvage");

        IERC20Upgradeable _target = IERC20Upgradeable(_token);
        _target.safeTransfer(treasury, _target.balanceOf(address(this)));
    }

    /**
     * @dev Add a new rebase hook.
     * @param _destination Destination contract for the reabase hook.
     * @param _data Transaction payload for the rebase hook.
     */
    function addTransaction(address _destination, bytes memory _data) external onlyGovernance {
        transactions.push(Transaction({enabled: true, destination: _destination, data: _data}));
    }

    /**
     * @dev Remove a rebase hook.
     * @param _index Index of the transaction to remove.
     */
    function removeTransaction(uint256 _index) external onlyGovernance {
        require(_index < transactions.length, "index out of bounds");

        if (_index < transactions.length - 1) {
            transactions[_index] = transactions[transactions.length - 1];
        }

        transactions.pop();
    }

    /**
     * @dev Updates an existing rebase hook transaction.
     * @param _index Index of transaction. Transaction ordering may have changed since adding.
     * @param _enabled True for enabled, false for disabled.
     */
    function updateTransaction(uint256 _index, bool _enabled) external onlyGovernance {
        require(_index < transactions.length, "index must be in range of stored tx list");
        transactions[_index].enabled = _enabled;
    }

    /**
     * @dev Returns the number of rebase hook transactions.
     */
    function transactionSize() external view returns (uint256) {
        return transactions.length;
    }

    uint256[50] private __gap;
}