// SPDX-License-Identifier: GPL-3.0
//        .-.                               .-.
//       / (_)         /      /       .--.-'
//      /      .-. ---/------/---.-. (  (_)`)    (  .-.   .-.
//     /      (  |   /      /  ./.-'_ `-.  /  .   )(  |   /  )
//  .-/.    .-.`-'-'/      /   (__.'_    )(_.' `-'  `-'-'/`-'
// (_/ `-._.                       (_.--'               /

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/ILATTE.sol";

contract LATTEV2 is ERC20("LATTEv2", "LATTE"), Ownable, AccessControl {
  using SafeERC20 for IERC20;
  // This is a packed array of booleans.
  mapping(uint256 => uint256) private claimedBitMap;

  /// @dev private state variables
  uint256 private _totalLock;
  mapping(address => uint256) private _locks;
  mapping(address => uint256) private _lastUnlockBlock;

  /// @dev public immutable state variables
  uint256 public immutable startReleaseBlock;
  uint256 public immutable endReleaseBlock;
  bytes32 public immutable merkleRoot;

  /// @dev public mutable state variables
  uint256 public cap;

  // V1 LATTE token
  IERC20 public immutable lattev1;

  bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE"); // role for setting up non-sensitive data
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE"); // role for minting stuff (owner + some delegated contract)
  address public constant DEAD_ADDR = 0x000000000000000000000000000000000000dEaD;

  /// @dev events
  event LogLock(address indexed to, uint256 value);
  event LogCapChanged(uint256 prevCap, uint256 newCap);
  // This event is triggered whenever a call to #claim succeeds.
  event LogClaimedLock(uint256 index, address indexed account, uint256 amount);
  event LogRedeem(address indexed account, uint256 indexed amount);

  constructor(IERC20 _lattev1, bytes32 _merkleRoot) public {
    require(address(_lattev1) != address(0), "LATTEV2::constructor::latte v1 cannot be a zero address");
    _setupDecimals(18);
    cap = uint256(-1);
    startReleaseBlock = ILATTE(address(_lattev1)).startReleaseBlock();
    endReleaseBlock = ILATTE(address(_lattev1)).endReleaseBlock();
    merkleRoot = _merkleRoot;
    lattev1 = _lattev1;

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(GOVERNOR_ROLE, _msgSender());
  }

  modifier beforeStartReleaseBlock() {
    require(
      block.number < startReleaseBlock,
      "LATTEV2::beforeStartReleaseBlock:: operation can only be done before start release"
    );
    _;
  }

  /// @dev only the one having a GOVERNOR_ROLE can continue an execution
  modifier onlyGovernor() {
    require(hasRole(GOVERNOR_ROLE, _msgSender()), "LATTEV2::onlyGovernor::only GOVERNOR role");
    _;
  }

  /// @dev only the one having a MINTER_ROLE can continue an execution
  modifier onlyMinter() {
    require(hasRole(MINTER_ROLE, _msgSender()), "LATTEV2::onlyMinter::only MINTER role");
    _;
  }

  /// @dev Return unlocked LATTE
  function unlockedSupply() external view returns (uint256) {
    return totalSupply().sub(totalLock());
  }

  /// @dev Return totalLocked LATTE
  function totalLock() public view returns (uint256) {
    return _totalLock;
  }

  /// @dev Set cap. Cap must lower than previous cap. Only Governor can adjust
  /// @param _cap The new cap
  function setCap(uint256 _cap) external onlyGovernor {
    require(_cap < cap, "LATTEV2::setCap::_cap must < cap");
    uint256 _prevCap = cap;
    cap = _cap;
    emit LogCapChanged(_prevCap, cap);
  }

  /// @dev A function to mint LATTE. This will be called by a minter only.
  /// @param _to The address of the account to get this newly mint LATTE
  /// @param _amount The amount to be minted
  function mint(address _to, uint256 _amount) external onlyMinter {
    require(totalSupply().add(_amount) < cap, "LATTEV2::mint::cap exceeded");
    _mint(_to, _amount);
  }

  /// @dev A generic transfer function
  /// @param _recipient The address of the account that will be credited
  /// @param _amount The amount to be moved
  function transfer(address _recipient, uint256 _amount) public virtual override returns (bool) {
    _transfer(_msgSender(), _recipient, _amount);
    return true;
  }

  /// @dev A generic transferFrom function
  /// @param _sender The address of the account that will be debited
  /// @param _recipient The address of the account that will be credited
  /// @param _amount The amount to be moved
  function transferFrom(
    address _sender,
    address _recipient,
    uint256 _amount
  ) public virtual override returns (bool) {
    _transfer(_sender, _recipient, _amount);
    _approve(
      _sender,
      _msgSender(),
      allowance(_sender, _msgSender()).sub(_amount, "LATTEV2::transferFrom::transfer amount exceeds allowance")
    );
    return true;
  }

  /// @dev Return the total balance (locked + unlocked) of a given account
  /// @param _account The address that you want to know the total balance
  function totalBalanceOf(address _account) external view returns (uint256) {
    return _locks[_account].add(balanceOf(_account));
  }

  /// @dev Return the locked LATTE of a given account
  /// @param _account The address that you want to know the locked LATTE
  function lockOf(address _account) external view returns (uint256) {
    return _locks[_account];
  }

  /// @dev Return unlock for a given account
  /// @param _account The address that you want to know the last unlock block
  function lastUnlockBlock(address _account) external view returns (uint256) {
    return _lastUnlockBlock[_account];
  }

  /// @dev Lock LATTE based-on the command from MasterBarista
  /// @param _account The address that will own this locked amount
  /// @param _amount The locked amount
  function lock(address _account, uint256 _amount) external onlyMinter {
    require(_account != address(this), "LATTEV2::lock::no lock to token address");
    require(_account != address(0), "LATTEV2::lock::no lock to address(0)");
    require(_amount <= balanceOf(_account), "LATTEV2::lock::no lock over balance");

    _lock(_account, _amount);
  }

  /// internal function for lock, there will be NO interaction here
  function _lock(address _account, uint256 _amount) internal {
    _transfer(_account, address(this), _amount);

    _locks[_account] = _locks[_account].add(_amount);
    _totalLock = _totalLock.add(_amount);

    if (_lastUnlockBlock[_account] < startReleaseBlock) {
      _lastUnlockBlock[_account] = startReleaseBlock;
    }

    emit LogLock(_account, _amount);
  }

  /// @dev Return how many LATTE is unlocked for a given account
  /// @param _account The address that want to check canUnlockAmount
  function canUnlockAmount(address _account) public view returns (uint256) {
    // When block number less than startReleaseBlock, no LATTEs can be unlocked
    if (block.number < startReleaseBlock) {
      return 0;
    }
    // When block number more than endReleaseBlock, all locked LATTEs can be unlocked
    else if (block.number >= endReleaseBlock) {
      return _locks[_account];
    }
    // When block number is more than startReleaseBlock but less than endReleaseBlock,
    // some LATTEs can be released
    else {
      uint256 releasedBlock = block.number.sub(_lastUnlockBlock[_account]);
      uint256 blockLeft = endReleaseBlock.sub(_lastUnlockBlock[_account]);
      return _locks[_account].mul(releasedBlock).div(blockLeft);
    }
  }

  /// @dev Claim unlocked LATTE after the release schedule is reached
  function unlock() external {
    require(_locks[msg.sender] > 0, "LATTEV2::unlock::no locked LATTE");

    uint256 amount = canUnlockAmount(msg.sender);

    _transfer(address(this), msg.sender, amount);
    _locks[msg.sender] = _locks[msg.sender].sub(amount);
    _lastUnlockBlock[msg.sender] = block.number;
    _totalLock = _totalLock.sub(amount);
  }

  /// @dev check whether or not the user already claimed
  function isClaimed(uint256 _index) public view returns (bool) {
    uint256 claimedWordIndex = _index / 256;
    uint256 claimedBitIndex = _index % 256;
    uint256 claimedWord = claimedBitMap[claimedWordIndex];
    uint256 mask = (1 << claimedBitIndex);
    return claimedWord & mask == mask;
  }

  /// @dev once an index (which is an account) claimed sth, set claimed
  function _setClaimed(uint256 _index) private {
    uint256 claimedWordIndex = _index / 256;
    uint256 claimedBitIndex = _index % 256;
    claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
  }

  /// @notice method for letting an account to claim lock from V1
  function claimLock(
    uint256[] calldata _indexes,
    address[] calldata _accounts,
    uint256[] calldata _amounts,
    bytes32[][] calldata _merkleProofs
  ) external beforeStartReleaseBlock {
    uint256 _total = 0;
    for (uint256 i = 0; i < _accounts.length; i++) {
      if (isClaimed(_indexes[i])) continue; // if some amounts already claimed their lock, continue to another one

      // Verify the merkle proof.
      bytes32 node = keccak256(abi.encodePacked(_indexes[i], _accounts[i], _amounts[i]));
      require(MerkleProof.verify(_merkleProofs[i], merkleRoot, node), "LATTEV2::claimLock:: invalid proof");

      _locks[_accounts[i]] = _amounts[i];
      _lastUnlockBlock[_accounts[i]] = startReleaseBlock; // set batch is always < startReleaseBlock
      _total = _total.add(_amounts[i]);

      // Mark it claimed
      _setClaimed(_indexes[i]);
      emit LogClaimedLock(_indexes[i], _accounts[i], _amounts[i]);
    }
    _mint(address(this), _total);
    _totalLock = _totalLock.add(_total);
  }

  /// @notice used for redeem a new token from the lagacy one, noted that the legacy one will be burnt as a result of redemption
  function redeem(uint256 _amount) external beforeStartReleaseBlock {
    // burn legacy token
    lattev1.safeTransferFrom(_msgSender(), DEAD_ADDR, _amount);

    // mint a new token
    _mint(_msgSender(), _amount);

    emit LogRedeem(_msgSender(), _amount);
  }
}
