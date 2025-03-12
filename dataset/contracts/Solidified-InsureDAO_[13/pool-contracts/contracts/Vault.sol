pragma solidity ^0.6.0;
/**
 * @author kohshiba
 * @title InsureDAO vault contract
 */
import "./libraries/tokens/IERC20.sol";
import "./libraries/tokens/SafeERC20.sol";
import "./libraries/math/SafeMath.sol";
import "./libraries/utils/Address.sol";
import "./interfaces/IController.sol";
import "./interfaces/IRegistry.sol";

contract Vault {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    /**
     * Storage
     */

    IERC20 public token;
    IController public controller;
    IRegistry public registry;

    mapping(address => uint256) public attributions;
    uint256 public totalAttributions;
    uint256 public debt;

    address public owner;
    address public future_owner;
    uint256 public transfer_ownership_deadline;
    uint256 public constant ADMIN_ACTIONS_DELAY = 3 * 86400;

    event CommitNewAdmin(uint256 deadline, address future_admin);
    event NewAdmin(address admin);
    event ControllerSet(address controller);

    constructor(
        address _token,
        address _registry,
        address _controller
    ) public {
        token = IERC20(_token);
        registry = IRegistry(_registry);
        controller = IController(_controller);
        owner = msg.sender;
    }

    /**
     * Vault Functions
     */

    /**
     * @notice A registered contract can deposit collateral and get attribution point in return
     */

    function addValue(
        uint256 _amount,
        address _from,
        address _beneficiary
    ) external returns (uint256 _attributions) {
        require(
            IRegistry(registry).isListed(msg.sender),
            "ERROR_ADD-VALUE_BADCONDITOONS"
        );
        uint256 _pool = valueAll();
        token.safeTransferFrom(_from, address(this), _amount);
        if (totalAttributions == 0) {
            _attributions = _amount;
        } else {
            _attributions = _amount.mul(totalAttributions).div(_pool);
        }
        totalAttributions = totalAttributions.add(_attributions);
        attributions[_beneficiary] = attributions[_beneficiary].add(
            _attributions
        );
    }

    /**
     * @notice an address that has balance in the vault can withdraw underlying value
     */

    function withdrawValue(uint256 _amount, address _to)
        external
        returns (uint256 _attributions)
    {
        require(
            attributions[msg.sender] > 0 &&
                underlyingValue(msg.sender) >= _amount,
            "ERROR_WITHDRAW-VALUE_BADCONDITOONS"
        );
        _attributions = totalAttributions.mul(_amount).div(valueAll());
        attributions[msg.sender] = attributions[msg.sender].sub(_attributions);
        totalAttributions = totalAttributions.sub(_attributions);
        if (available() < _amount) {
            uint256 _shortage = _amount.sub(available());
            _unutilize(_shortage);
        }
        token.transfer(_to, _amount);
    }

    /**
     * @notice an address that has balance in the vault can transfer underlying value
     */

    function transferValue(uint256 _amount, address _destination) external {
        require(
            attributions[msg.sender] > 0 &&
                underlyingValue(msg.sender) >= _amount,
            "ERROR_TRANSFER-VALUE_BADCONDITOONS"
        );
        uint256 _targetAttribution = _amount.mul(totalAttributions).div(
            valueAll()
        );
        attributions[msg.sender] = attributions[msg.sender].sub(
            _targetAttribution
        );
        attributions[_destination] = attributions[_destination].add(
            _targetAttribution
        );
    }

    /**
     * @notice an address that has balance in the vault can withdraw value denominated in attribution
     */
    function withdrawAttribution(uint256 _attribution, address _to)
        external
        returns (uint256 _retVal)
    {
        require(
            attributions[msg.sender] > _attribution,
            "ERROR_WITHDRAW-ATTRIBUTION_BADCONDITOONS"
        );
        _retVal = _attribution.mul(valueAll()).div(totalAttributions);
        attributions[msg.sender] = attributions[msg.sender].sub(_attribution);
        if (available() < _retVal) {
            uint256 _shortage = _retVal.sub(available());
            _unutilize(_shortage);
        }
        token.transfer(_to, _retVal);
    }

    /**
     * @notice an address that has balance in the vault can withdraw all value
     */
    function withdrawAllAttribution(address _to)
        external
        returns (uint256 _retVal)
    {
        require(
            attributions[msg.sender] > 0,
            "ERROR_WITHDRAW-ALL-ATTRIBUTION_BADCONDITOONS"
        );
        _retVal = attributions[msg.sender].mul(valueAll()).div(
            totalAttributions
        );

        attributions[msg.sender] = 0;
        if (available() < _retVal) {
            uint256 _shortage = _retVal.sub(available());
            _unutilize(_shortage);
        }
        token.transfer(_to, _retVal);
    }

    /**
     * @notice an address that has balance in the vault can transfer value denominated in attribution
     */
    function transferAttribution(uint256 _amount, address _destination)
        external
    {
        require(
            attributions[msg.sender] > 0 && attributions[msg.sender] >= _amount,
            "ERROR_TRANSFER-ATTRIBUTION_BADCONDITOONS"
        );
        attributions[msg.sender] = attributions[msg.sender].sub(_amount);
        attributions[_destination] = attributions[_destination].add(_amount);
    }

    /**
     * @notice the controller can utilize all available stored funds
     */
    function utilize() external returns (uint256 _amount) {
        _amount = available();
        if (_amount > 0) {
            token.safeTransfer(address(controller), _amount);
            controller.earn(address(token), _amount);
        }
    }

    /**
     * @notice get attribution number for the specified address
     */

    function attributionOf(address _target) external view returns (uint256) {
        return attributions[_target];
    }

    /**
     * @notice get all attribution number for this contract
     */
    function attributionAll() external view returns (uint256) {
        return totalAttributions;
    }

    /**
     * @notice Convert attribution number into underlying assset value
     */
    function attributionValue(uint256 _attribution)
        external
        view
        returns (uint256)
    {
        if (totalAttributions > 0 && _attribution > 0) {
            return _attribution.mul(valueAll()).div(totalAttributions);
        } else {
            return 0;
        }
    }

    /**
     * @notice return underlying value of the specified address
     */
    function underlyingValue(address _target) public view returns (uint256) {
        if (attributions[_target] > 0) {
            return valueAll().mul(attributions[_target]).div(totalAttributions);
        } else {
            return 0;
        }
    }

    /**
     * @notice return underlying value of this contract
     */
    function valueAll() public view returns (uint256) {
        return token.balanceOf(address(this)).add(controller.valueAll());
    }

    /**
     * @notice admin function to set controller address
     */
    function setController(address _controller) public {
        require(msg.sender == owner, "dev: only owner");
        controller.migrate(address(_controller));
        controller = IController(_controller);
        emit ControllerSet(_controller);
    }

    /**
     * @notice internal function to unutilize the funds and keep utilization rate
     */
    function _unutilize(uint256 _amount) internal {
        controller.withdraw(address(this), _amount);
    }

    /**
     * @notice return how much funds in this contract is available to be utilized
     */
    function available() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice return how much price for each attribution
     */
    function getPricePerFullShare() public view returns (uint256) {
        return valueAll().mul(1e18).div(totalAttributions);
    }

    /**
     * Ownership Functions
     */

    /**
     * @notice Commit ownership change transaction
     */
    function commit_transfer_ownership(address _owner) external {
        require(msg.sender == owner, "dev: only owner");
        require(transfer_ownership_deadline == 0, "dev: active transfer");

        uint256 _deadline = block.timestamp.add(ADMIN_ACTIONS_DELAY);
        transfer_ownership_deadline = _deadline;
        future_owner = _owner;

        emit CommitNewAdmin(_deadline, _owner);
    }

    /**
     * @notice Execute ownership change transaction
     */
    function apply_transfer_ownership() external {
        require(msg.sender == owner, "dev: only owner");
        require(
            block.timestamp >= transfer_ownership_deadline,
            "dev: insufficient time"
        );
        require(transfer_ownership_deadline != 0, "dev: no active transfer");

        transfer_ownership_deadline = 0;
        address _owner = future_owner;

        owner = _owner;

        emit NewAdmin(owner);
    }
}
