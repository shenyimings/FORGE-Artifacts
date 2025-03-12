// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../farm/interfaces/IMasterBarista.sol";
import "../farm/interfaces/IMasterBaristaCallback.sol";
import "./interfaces/IBoosterConfig.sol";
import "./interfaces/IOGOwnerToken.sol";
import "./LatteNFT.sol";

contract OGNFT is LatteNFT, ReentrancyGuardUpgradeable, IMasterBaristaCallback {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  mapping(uint256 => IOGOwnerToken) public ogOwnerToken;

  IMasterBarista public masterBarista;
  IERC20Upgradeable public latte;
  mapping(uint256 => mapping(address => EnumerableSetUpgradeable.UintSet)) internal _userStakeTokenIds;

  event SetOgOwnerToken(uint256 indexed categoryId, address indexed ogOwnerToken);
  event Harvest(address indexed user, uint256 indexed categoryId, uint256 balance);
  event Stake(address indexed user, uint256 indexed categoryId, uint256 tokenId);
  event Unstake(address indexed user, uint256 indexed categoryId, uint256 tokenId);

  function initialize(
    string memory _baseURI,
    IERC20Upgradeable _latte,
    IMasterBarista _masterBarista
  ) public initializer {
    LatteNFT.initialize(_baseURI);

    masterBarista = _masterBarista;
    latte = _latte;
  }

  /// @notice check whether this token's category id has an og owner token set
  modifier withOGOwnerToken(uint256 _tokenId) {
    require(
      address(ogOwnerToken[latteNFTToCategory[_tokenId]]) != address(0),
      "OGNFT::withOGOwnerToken:: og owner token not set"
    );
    _;
  }

  /// @notice setCategoryOGOwnerToken for setting an ogOwnerToken with regard to a category id
  /// @param _categoryId - a category id
  /// @param _ogOwnerToken - BEP20 og token for staking at a master barista
  function setCategoryOGOwnerToken(uint256 _categoryId, address _ogOwnerToken) external onlyGovernance {
    ogOwnerToken[_categoryId] = IOGOwnerToken(_ogOwnerToken);

    emit SetOgOwnerToken(_categoryId, _ogOwnerToken);
  }

  /// @dev Internal function for withdrawing a boosted stake token and receive a reward from a master barista
  /// @param _categoryId specified category id
  /// @param _shares user's shares to be withdrawn
  function _withdrawFromMasterBarista(uint256 _categoryId, uint256 _shares) internal {
    if (_shares == 0) return;
    masterBarista.withdraw(_msgSender(), address(ogOwnerToken[_categoryId]), _shares);
  }

  /// @dev Internal function for harvest a reward from a master barista
  /// @param _user harvester
  /// @param _categoryId specified category Id
  function _harvestFromMasterBarista(address _user, uint256 _categoryId) internal {
    address stakeToken = address(ogOwnerToken[_categoryId]);
    (uint256 userStakeAmount, , , ) = masterBarista.userInfo(stakeToken, _user);
    if (userStakeAmount == 0) {
      emit Harvest(_user, _categoryId, 0);
      return;
    }
    uint256 beforeReward = latte.balanceOf(_user);
    masterBarista.harvest(_user, stakeToken);

    emit Harvest(_user, _categoryId, latte.balanceOf(_user).sub(beforeReward));
  }

  /// @notice for staking a stakeToken and receive some rewards
  /// @param _tokenId a tokenId
  function stake(uint256 _tokenId) external whenNotPaused nonReentrant withOGOwnerToken(_tokenId) {
    transferFrom(_msgSender(), address(this), _tokenId);
    _stake(_tokenId, _msgSender());
  }

  /// @dev internal function for stake
  function _stake(uint256 _tokenId, address _for) internal {
    uint256 categoryId = latteNFTToCategory[_tokenId];
    IOGOwnerToken stakeToken = ogOwnerToken[categoryId];
    _userStakeTokenIds[categoryId][_for].add(_tokenId);

    _harvestFromMasterBarista(_for, categoryId);
    stakeToken.mint(address(this), 1 ether);
    IERC20Upgradeable(address(stakeToken)).safeApprove(address(masterBarista), 1 ether);

    masterBarista.deposit(_for, address(stakeToken), 1 ether);

    IERC20Upgradeable(address(stakeToken)).safeApprove(address(masterBarista), 0);

    emit Stake(_for, categoryId, _tokenId);
  }

  /// @dev internal function for unstaking a stakeToken and receive some rewards
  /// @param _tokenId a tokenId
  function _unstake(uint256 _tokenId) internal {
    uint256 categoryId = latteNFTToCategory[_tokenId];
    require(
      _userStakeTokenIds[categoryId][_msgSender()].contains(_tokenId),
      "OGNFT::_unstake:: invalid token to be unstaked"
    );
    IOGOwnerToken stakeToken = ogOwnerToken[categoryId];
    _userStakeTokenIds[categoryId][_msgSender()].remove(_tokenId);

    _withdrawFromMasterBarista(categoryId, 1 ether);
    stakeToken.burn(address(this), 1 ether);
    _transfer(address(this), _msgSender(), _tokenId);
    emit Unstake(_msgSender(), categoryId, _tokenId);
  }

  /// @dev function for unstaking a stakeToken and receive some rewards
  /// @param _tokenId a tokenId
  function unstake(uint256 _tokenId) external whenNotPaused withOGOwnerToken(_tokenId) nonReentrant {
    _unstake(_tokenId);
  }

  /// @notice function for harvesting the reward
  /// @param _tokenId a tokenId
  function harvest(uint256 _tokenId) external whenNotPaused withOGOwnerToken(_tokenId) nonReentrant {
    _harvestFromMasterBarista(_msgSender(), latteNFTToCategory[_tokenId]);
  }

  /// @notice function for harvesting rewards in specified staking tokens
  /// @param _tokenIds a set of tokenId to be harvested
  function harvest(uint256[] calldata _tokenIds) external whenNotPaused nonReentrant {
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      require(address(ogOwnerToken[_tokenIds[i]]) != address(0), "OGNFT::harvest:: og owner token not set");
      _harvestFromMasterBarista(_msgSender(), latteNFTToCategory[_tokenIds[i]]);
    }
  }

  /// @notice mint with stake the nft
  /// @inheritdoc LatteNFT
  function mint(
    address _to,
    uint256 _categoryId,
    string calldata _tokenURI
  ) public override returns (uint256) {
    uint256 currId = currentTokenId();
    LatteNFT.mint(address(this), _categoryId, _tokenURI);
    _stake(currId, _to);
  }

  /// @dev a notifier function for letting some observer call when some conditions met
  /// @dev currently, the caller will be a master barista calling before a latte lock
  function masterBaristaCall(
    address, /*stakeToken*/
    address, /*userAddr*/
    uint256 /*reward*/
  ) external override {
    return;
  }
}
