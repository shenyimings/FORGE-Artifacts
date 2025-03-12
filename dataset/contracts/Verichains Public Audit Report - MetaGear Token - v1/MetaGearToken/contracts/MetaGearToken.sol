pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import './UsingLiquidityProtectionService.sol';

contract MetaGearToken is ERC20Snapshot, Pausable, AccessControl, UsingLiquidityProtectionService(0x0649601Ca10D68792AA0285bD25E1E5938FED8E5) {
    using SafeMath for uint256;

    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 private constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 private initialTokensSupply = 1000000000 * 10 ** decimals();
    mapping(address => bool) private blackListedList;

    constructor() ERC20("MetaGear Token", "GEAR") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _mint(msg.sender, initialTokensSupply);
    }

    function snapshot() external onlyRole(ADMIN_ROLE) {
        _snapshot();
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount)
    public
    virtual
    onlyRole(BURNER_ROLE)
    {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
    unchecked {
        _approve(account, _msgSender(), currentAllowance - amount);
    }
        _burn(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!blackListedList[from] && !blackListedList[to], "Address is blacklisted");
        super._beforeTokenTransfer(from, to, amount);
        LiquidityProtection_beforeTokenTransfer(from, to, amount);
    }

    function isBacklisted(address _address) external view returns (bool) {
        return blackListedList[_address];
    }

    function addBlackList(address _address) external onlyRole(ADMIN_ROLE) {
        blackListedList[_address] = true;
    }

    function removeBlackList(address _address) external onlyRole(ADMIN_ROLE) {
        blackListedList[_address] = false;
    }

    function getBurnedTotal() external view returns (uint256 _amount) {
        return initialTokensSupply.sub(totalSupply());
    }

    function withdrawBalance() public onlyRole(ADMIN_ROLE) {
        address payable _owner = payable(_msgSender());
        _owner.transfer(address(this).balance);
    }

    function withdrawTokens(address _tokenAddr, address _to)
    public
    onlyRole(ADMIN_ROLE)
    {
        require(
            _tokenAddr != address(this),
            "Cannot transfer out tokens from contract!"
        );
        require(isContract(_tokenAddr), "Need a contract address");
        ERC20(_tokenAddr).transfer(
            _to,
            ERC20(_tokenAddr).balanceOf(address(this))
        );
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    modifier notBlackListed() {
        require(!blackListedList[msg.sender], "Address is blacklisted");
        _;
    }


    function token_transfer(address _from, address _to, uint _amount) internal override {
        _transfer(_from, _to, _amount);
        // Expose low-level token transfer function.
    }

    function token_balanceOf(address _holder) internal view override returns (uint) {
        return balanceOf(_holder);
        // Expose balance check function.
    }

    function protectionAdminCheck() internal view override onlyRole(ADMIN_ROLE) {} // Must revert to deny access.
    function uniswapVariety() internal pure override returns (bytes32) {
        return PANCAKESWAP;
        // UNISWAP / PANCAKESWAP / QUICKSWAP / SUSHISWAP / PANGOLIN / TRADERJOE.
    }

    function uniswapVersion() internal pure override returns (UniswapVersion) {
        return UniswapVersion.V2;
        // V2 or V3.
    }

    function uniswapFactory() internal pure override returns (address) {
        return 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
        // PancakeFactory
    }
    // All the following overrides are optional, if you want to modify default behavior.

    // How the protection gets disabled.
    function protectionChecker() internal view override returns (bool) {
        return ProtectionSwitch_manual();
    }

    // This token will be pooled in pair with:
    function counterToken() internal pure override returns (address) {
        return 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        // WBNB
    }

}