pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../../../contracts/yield/interface/IYieldModule.sol";
import "../../../contracts/common/Rescuable.sol";

abstract contract BaseModuleUpgradedMock is IYieldModule, UUPSUpgradeable, OwnableUpgradeable, Rescuable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice The smart farmooor of the module
    address public smartFarmooor;
    /// @notice The dex used to swap the rewards
    address public dex;
    /// @notice The manager of the module
    address public manager;
    /// @notice The asset used by the module
    address public baseToken;
    /// @notice The fee in native token that has to be paid in case of async withdrawal
    uint256 public executionFee;
    /// @notice The list of rewards earned by the module
    address[] public rewards;
    /// @notice Name of the Module
    string public name;
    /// @notice Name of the Module
    uint public dummyBaseModule;
    /// @notice Wrapped Native Token address
    address public wrappedNativeToken;
    /// @dev Reserved storage space to allow for layout changes in the future
    uint256[50] private ______gap;

    modifier onlyOwnerOrManager() {
        require(
            msg.sender == owner() || msg.sender == manager,
            "BaseModule: only manager or owner"
        );
        _;
    }

    modifier onlySmartFarmooor() {
        require(msg.sender == smartFarmooor, "BaseModule: only smart farmooor");
        _;
    }

    /** proxy **/

    function _initializeV2Base(uint dummy) public {
    dummyBaseModule = dummy;
    }
    /**
     * @notice  Initializes
     * @dev     Should always be called on deployment
     * @param   _smartFarmooor Smart Farmooor of the module
     * @param   _manager  Manager of the Module
     * @param   _baseToken  Asset contract address
     * @param   _executionFee  Execution fee for withdrawals
     * @param   _dex  Dex Router contract address
     * @param   _rewards  Reward contract addresses.
     * @param   _name  Name of the Module
     */
    function _initializeBase(
        address _smartFarmooor,
        address _manager,
        address _baseToken,
        uint256 _executionFee,
        address _dex,
        address[] memory _rewards,
        string memory _name
    ) internal {
        __UUPSUpgradeable_init();
        __Ownable_init();

        _setSmartFarmooor(_smartFarmooor);
        _setDex(_dex);
        _setManager(_manager);
        _setBaseToken(_baseToken);
        _setExecutionFee(_executionFee);
        _setRewards(_rewards);
        _setName(_name);
        _approveDex();
    }

    /**
     * @notice  Upgrade to new implementation contract
     * @dev     Point to new implementation contract
     * @param   newImplementation Contract address of newImplementation
     */
    function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyOwner
    {}

    /**
     * @notice  Get current implementation contract
     * @return  address  Returns current implement contract
     */
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    /** admin **/

    /**
     * @notice  Set Dex contract address
     * @param   _dex  Dex contract address
     */
    function setDex(address _dex) external onlyOwner {
        _setDex(_dex);
        _approveDex();
    }

    /**
     * @notice  Set execution fee contract address
     * @dev     AVAX Amount
     * @param   _executionFee  New execution fee
     */
    function setExecutionFee(uint256 _executionFee) external onlyOwner {
        _setExecutionFee(_executionFee);
    }

    /**
     * @notice  Set new reward tokens
     * @dev     Set an old reward token address to address(0) in case it should be disabled. Order of reward tokens matter in the array : reward/incentives token address then Native token
     * @param   _rewards  Array of new reward token
     */
    function setRewards(address[] memory _rewards) external onlyOwner {
        _setRewards(_rewards);
        _approveDex();
    }

    /**
     * @notice  Approve dex router contract address as spender
     */
    function approveDex() external onlyOwner {
        _approveDex();
    }

    /**
     * @notice  Rescue any ERC20 token stuck on the contract
     * @param   token  Contract address of the token to rescue
     */
    function rescueToken(address token) external onlyOwner {
        require(_lpToken() != address(0) && _lpToken() != token, "BaseModule: can't pull out lp tokens");
        _rescueToken(token);
    }

    /**
     * @notice  Rescue Native token stuck on the contract
     */
    function rescueNative() external onlyOwner {
        _rescueNative();
    }

    /** helper **/

    /**
     * @notice  Set the Smart Farmooor of the Module
     * @param   _smartFarmooor  Address of the Smart Farmooor
     */
    function _setSmartFarmooor(address _smartFarmooor) private {
        require(
            _smartFarmooor != address(0),
            "BaseModule: cannot be the zero address"
        );
        smartFarmooor = _smartFarmooor;
    }

    /**
     * @notice  Set Dex contract address
     * @param   _dex  Dex contract address
     */
    function _setDex(address _dex) private {
        require(
            _dex != address(0),
            "BaseModule: cannot be the zero address"
        );
        dex = _dex;
    }

    /**
     * @notice  Set the Manager of the Module
     * @param   _manager  Address of the Manager
     */
    function _setManager(address _manager) private {
        require(
            _manager != address(0),
            "BaseModule: cannot be the zero address"
        );
        manager = _manager;
    }

    /**
     * @notice  Set the Base token of the Module
     * @param   _baseToken  Address of the Base token contract
     */
    function _setBaseToken(address _baseToken) private {
        require(
            _baseToken != address(0),
            "BaseModule: cannot be the zero address"
        );
        baseToken = _baseToken;
    }

    /**
     * @notice  Set execution fee contract address
     * @dev     AVAX Amount
     * @param   _executionFee  New execution fee
     */
    function _setExecutionFee(uint256 _executionFee) private {
        require(
            _executionFee <= 5 * 1e17,
            "BaseModule: execution fee must be less than 0.5 AVAX"
        );
        executionFee = _executionFee;
    }

    /**
     * @notice  Set new reward tokens
     * @dev     Set an old reward token address to address(0) in case it should be disabled. Order of reward tokens matter in the array : Native then reward/incentives token address
     * @param   _rewards  Array of new reward token
     */
    function _setRewards(address[] memory _rewards) private {
        for (uint256 i = 0; i < _rewards.length; i++) {
            require(
                _rewards[i] != address(0),
                "BaseModule: cannot be the zero address"
            );
        }
        rewards = _rewards;
    }

    function _setName(string memory _name) private {
        name = _name;
    }

    /**
     * @notice  Approve dex router contract address as spender
     */
    function _approveDex() private {
        require(dex != address(0), "BaseModule: dex not initialized");
        require(rewards.length > 0, "BaseModule: rewards not initialized");
        for (uint256 i = 0; i < rewards.length; i++) {
            uint256 allowance = IERC20Upgradeable(rewards[i]).allowance(
                address(this),
                dex
            );
            if (allowance == 0) {
                IERC20Upgradeable(rewards[i]).safeApprove(dex, type(uint256).max);
            } else {
                IERC20Upgradeable(rewards[i]).safeIncreaseAllowance(
                    dex,
                    type(uint256).max - allowance
                );
            }
        }
    }

    /**
     * @notice  Function to override in each module with it's lp token address
     * @dev     overridden in each module implementation
     * @return  lp token address
     */
    function _lpToken() internal virtual returns (address) {
        return address(0);
    }

    /** fallback **/

    receive() external payable {}
}
