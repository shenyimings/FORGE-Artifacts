// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "../citizenid/CitizenIDV1.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/// @title A Karma Point contract
/// @author Tevaera Labs
/// @notice A contract to buy/withdraw ERC20 Karma Points
/// @dev It extends ERC20 standard
contract KarmaPointV1 is
    ERC20Upgradeable,
    ERC20CappedUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    CitizenIDV1 private citizenIdContract;

    // The claim contract address
    address public claimContract;
    // True, if the owner permits claiming of KPs for the time being
    bool public canClaim = false;

    // True, if the owner permits KP transfer
    bool public canTransfer = false;

    // 1 KP = ??
    uint256 public price;

    address payable public safeAddress;

    uint256 public buyCap;

    mapping(address => uint256) public boughtKP;

    mapping(address => uint256) public toBeClaimedKP;

    struct TevanBalance {
        address tevan;
        uint256 amount;
    }

    modifier isTevan() {
        require(citizenIdContract.balanceOf(msg.sender) > 0, "Not a Tevan");
        _;
    }

    modifier isNotBlacklisted() {
        require(
            !citizenIdContract.blacklisted(msg.sender),
            "Tevan Blacklisted!"
        );
        _;
    }

    /// @dev Emitted when karma points are minted or transferred
    event kpTransfer(
        address indexed src,
        address indexed dest,
        uint256 kp,
        uint256 kpBalance
    );

    /// @dev Initializes the upgradable contract
    /// @param _citizenIdContract the citizen id contract address
    /// @param _safeAddress the safe address
    /// @param _price the price of karma point
    /// @param _totalSupplyCap the total supply cap for karma points
    /// @param _buyCap the buy cap per user
    function initialize(
        CitizenIDV1 _citizenIdContract,
        address payable _safeAddress,
        uint256 _price,
        uint256 _totalSupplyCap,
        uint256 _buyCap
    ) external initializer {
        __ERC20_init("KarmaPoint", "KP");
        __ERC20Capped_init(_totalSupplyCap);
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        buyCap = _buyCap;
        citizenIdContract = _citizenIdContract;
        safeAddress = _safeAddress;
        price = _price;
    }

    /// @dev Allows owner to pause sale if active
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Allows owner to acticvate sale
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /// @dev Allows user to withdraw karma points to game by burning it on-chain
    /// @param amount the number of KPs the player wants to withdraw or burn on-chain
    function withdraw(
        uint256 amount
    ) external isTevan isNotBlacklisted nonReentrant whenNotPaused {
        _burn(msg.sender, amount);
    }

    /// @dev Allows user to buy ERC20 karma points against ETH
    /// @param kpAmount the number of KPs the user wnats to buy
    function buy(
        uint256 kpAmount
    ) external payable isTevan isNotBlacklisted nonReentrant whenNotPaused {
        // make sure if doesn't exceed the total cap
        require(totalSupply() + kpAmount <= cap(), "Exceeds total cap");
        // make sure if doesn't exceed the individual buying cap
        uint256 kpBalance = kpAmount + boughtKP[msg.sender];
        require(kpBalance <= buyCap, "Exceeds buying cap");
        // make sure the amount passed is matching the kp value
        require(msg.value == getPrice(kpAmount), "Invalid amount");

        boughtKP[msg.sender] += kpAmount;
        _mint(msg.sender, kpAmount);
    }

    /// @dev Withdraws funds from this contract to safe address
    function withdrawFunds() external onlyOwner {
        // make sure safe address is configured
        require(safeAddress != address(0), "Missing safe address!");

        (bool safeTxSuccess, ) = payable(safeAddress).call{
            value: (address(this).balance)
        }("");
        require(safeTxSuccess, "Transfer to safe address failed.");
    }

    /// @dev Allows owner to update transfer capability
    /// @param flag a flag to indicate whether to enable or disable the capability
    function updateTransferCapability(bool flag) external onlyOwner {
        canTransfer = flag;
    }

    /// @dev Allows owner to update claim capability
    /// @param _claimContract the claim contract address
    /// @param _canClaim a flag to indicate whether to enable or disable the capability
    function updateClaimCapability(
        address _claimContract,
        bool _canClaim
    ) external onlyOwner {
        claimContract = _claimContract;
        canClaim = _canClaim;
    }

    /// @dev Allows user to claim their airdropped karma points
    function claim(
        address tevan
    ) external isNotBlacklisted nonReentrant whenNotPaused {
        require(canClaim, "kp claim not enabled");

        uint256 kp = toBeClaimedKP[tevan];
        toBeClaimedKP[tevan] = 0;
        _mint(tevan, kp);
    }

    /// @dev Allows owner to airdrop karma points based on the off-chain data
    /// @param tevans a list of user with the points to airdrop
    function sync(
        address[] calldata tevans,
        uint256[] calldata amounts
    ) external onlyOwner {
        uint256 len = tevans.length;
        require(len == amounts.length, "Different arrays lengths");

        for (uint256 i = 0; i < len; ) {
            require(tevans[i] != address(0), "Zero Address");
            require(amounts[i] > 0, "KP <= 0");

            toBeClaimedKP[tevans[i]] += amounts[i];

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns the amount of stable coins required for specified karma points
    /// @param kpAmount the number of karma points
    /// @return uint256 the amount of stable coins required
    function getPrice(uint256 kpAmount) public view returns (uint256) {
        return (price * kpAmount);
    }

    /// @dev Allows owner to update the price for karma points
    /// @param _price a price of karma points in stable coins
    function updatePrice(uint256 _price) external onlyOwner {
        require(_price > 0, "Invalid price");
        price = _price;
    }

    /// @dev Allows owner to update the citizen id contract address
    /// @param _citizenIdContract a citizen id contract address
    function updateCitizenIdContract(
        CitizenIDV1 _citizenIdContract
    ) external onlyOwner {
        citizenIdContract = _citizenIdContract;
    }

    /// @dev Allows owner to update the safe wallet address
    /// @param _safeAddress the safe wallet address
    function updateSafeAddress(
        address payable _safeAddress
    ) external onlyOwner {
        require(_safeAddress != address(0), "Invalid address!");
        safeAddress = _safeAddress;
    }

    /// @dev Overriding the decimals value for Karma Point tokens to 0
    /// @return uint8 the number of decimals
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /// @dev Overridden the _transfer() function for additional checks
    /// @param from an address of sender
    /// @param to an address of receiver
    /// @param amount the amount being transferred
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            canTransfer && from != address(0) && to != address(0),
            "Unauthorized"
        );
        // sender and receiver should not be blacklisted
        require(!citizenIdContract.blacklisted(from), "Sender Blacklisted!");
        require(!citizenIdContract.blacklisted(to), "Receiver Blacklisted!");
        // receiver should have citizenship
        require(
            citizenIdContract.balanceOf(to) > 0,
            "Receiver is not a Tevan!"
        );

        super._transfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        emit kpTransfer(from, to, amount, balanceOf(to));
    }

    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        super._mint(to, amount);
    }
}
