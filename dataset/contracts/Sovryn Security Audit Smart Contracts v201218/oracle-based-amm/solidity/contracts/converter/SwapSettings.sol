pragma solidity 0.4.26;

import "../utility/Owned.sol";

contract SwapSettings is Owned {
  uint32 internal constant PROTOCOL_FEE_RESOLUTION = 1000000;
  address public wrbtcAddress;
	address public sovTokenAddress;
	address public feesController;
  uint32 public protocolFee;

  /**
	 * @dev triggered when the protocol fee sorage is set/updated
	 *
	 * @param _prevProtocolFee previous protocol fee percentage
	 * @param _newProtocolFee new protocol fee percentage
	 */
	event ProtocolFeeUpdate(uint32 _prevProtocolFee, uint32 _newProtocolFee);

	/**
	 * @dev triggered when new feesController is set.
	 *
	 * @param sender the one who initiated the changes.
	 * @param oldController old controller.
	 * @param newController new controller.
	 */
	event SetFeesController(address indexed sender, address indexed oldController, address indexed newController);

	/**
	 * @dev triggered when wrbtc address is set.
	 *
	 * @param sender the one who initiated the changes.
	 * @param oldWrbtcAddress old wrbtc address.
	 * @param newWrbtcAddress new wrbtc address.
	 *
	 */
	event SetWrbtcAddress(address indexed sender, address indexed oldWrbtcAddress, address indexed newWrbtcAddress);

	/**
	 * @dev triggered when wrbtc address is set.
	 *
	 * @param sender the one who initiated the changes.
	 * @param oldSOVTokenAddress old wrbtc address.
	 * @param newSOVTokenAddress new wrbtc address.
	 *
	 */
	event SetSOVTokenAddress(address indexed sender, address indexed oldSOVTokenAddress, address indexed newSOVTokenAddress);

  constructor(address _feesController, address _wrbtcAddress, address _sovTokenAddress, uint32 _protocolFee) public {
    require(_feesController != address(0), "ERR_ZERO_ADDRESS");
    require(_wrbtcAddress != address(0), "ERR_ZERO_ADDRESS");
    require(_sovTokenAddress != address(0), "ERR_ZERO_ADDRESS");
    require(_protocolFee <= PROTOCOL_FEE_RESOLUTION, "ERR_PROTOCOL_FEE_TOO_HIGH");

    feesController = _feesController;
    wrbtcAddress = _wrbtcAddress;
    sovTokenAddress = _sovTokenAddress;
    protocolFee = _protocolFee;

    emit SetFeesController(msg.sender, address(0), _feesController);
    emit SetWrbtcAddress(msg.sender, address(0), _wrbtcAddress);
    emit SetSOVTokenAddress(msg.sender, address(0), _sovTokenAddress);
    emit ProtocolFeeUpdate(0, _protocolFee);
  }

  /**
	 * @notice Set the feesController (The one who can withdraw / collect the protocolFee from this converter)
	 *
	 * @param newController new feesController
	 */
	function setFeesController(address newController) external ownerOnly() {
		require(newController != address(0), "ERR_ZERO_ADDRESS");
		address oldController = feesController;
		feesController = newController;

		emit SetFeesController(msg.sender, oldController, newController);
	}

	/**
	 * @notice Set the wrBTC contract address.
	 *
	 * @param newWrbtcAddress The address of the wrBTC contract.
	 * */
	function setWrbtcAddress(address newWrbtcAddress) external ownerOnly() {
		require(newWrbtcAddress != address(0), "ERR_ZERO_ADDRESS");
		address oldwrbtcAddress = address(wrbtcAddress);
		wrbtcAddress = newWrbtcAddress;

		emit SetWrbtcAddress(msg.sender, oldwrbtcAddress, newWrbtcAddress);
	}

	/**
	 * @notice Set the SOVToken contract address.
	 *
	 * @param newSOVTokenAddress The address of the SOV Token contract.
	 * */
	function setSOVTokenAddress(address newSOVTokenAddress) external ownerOnly() {
		require(newSOVTokenAddress != address(0), "ERR_ZERO_ADDRESS");
		address oldSOVTokenAddress = address(sovTokenAddress);
		sovTokenAddress = newSOVTokenAddress;

		emit SetSOVTokenAddress(msg.sender, oldSOVTokenAddress, newSOVTokenAddress);
	}

	/**
	 * @dev allows the owner to update the x% of protocol fee
	 *
	 * @param _protocolFee x% of protocol fee
	 */
	function setProtocolFee(uint32 _protocolFee) public ownerOnly() {
    require(_protocolFee <= PROTOCOL_FEE_RESOLUTION, "ERR_PROTOCOL_FEE_TOO_HIGH");
		emit ProtocolFeeUpdate(protocolFee, _protocolFee);
		protocolFee = _protocolFee;
	}

}