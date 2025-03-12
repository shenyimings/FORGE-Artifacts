pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interface/IRegistry.sol";
import "./Config.sol";
import "./Storage.sol";
import "./lib/LibParam.sol";

/**
 * @title The entrance of Furucombo
 * @author Ben Huang
 */
contract Proxy is Storage, Config {
    using Address for address;
    using SafeERC20 for IERC20;
    using LibParam for bytes32;

    // keccak256 hash of "furucombo.handler.registry"
    // prettier-ignore
    bytes32 private constant HANDLER_REGISTRY = 0x6874162fd62902201ea0f4bf541086067b3b88bd802fac9e150fd2d1db584e19;

    constructor(address registry) public {
        bytes32 slot = HANDLER_REGISTRY;
        assembly {
            sstore(slot, registry)
        }
    }

    /**
     * @notice Direct transfer from EOA should be reverted.
     * @dev Callback function will be handled here.
     */
    fallback() external payable {
        require(Address.isContract(msg.sender), "Not allowed from EOA");

        // If triggered by a function call, caller should be registered in registry.
        // The function call will then be forwarded to the location registered in
        // registry.
        if (msg.data.length != 0) {
            require(_isValid(msg.sender), "Invalid caller");

            address target =
                address(bytes20(IRegistry(_getRegistry()).infos(msg.sender)));
            bytes memory result = _exec(target, msg.data);

            // return result for aave v2 flashloan()
            uint256 size = result.length;
            assembly {
                let loc := add(result, 0x20)
                return(loc, size)
            }
        }
    }

    /**
     * @notice Combo execution function. Including three phases: pre-process,
     * exection and post-process.
     * @param tos The handlers of combo.
     * @param configs The configurations of executing cubes.
     * @param datas The combo datas.
     */
    function batchExec(
        address[] memory tos,
        bytes32[] memory configs,
        bytes[] memory datas
    ) public payable {
        _preProcess();
        _execs(tos, configs, datas);
        _postProcess();
    }

    /**
     * @notice The execution interface for callback function to be executed.
     * @dev This function can only be called through the handler, which makes
     * the caller become proxy itself.
     */
    function execs(
        address[] memory tos,
        bytes32[] memory configs,
        bytes[] memory datas
    ) public payable {
        require(msg.sender == address(this), "Does not allow external calls");
        require(_getSender() != address(0), "Sender should be initialized");
        _execs(tos, configs, datas);
    }

    /**
     * @notice The execution phase.
     * @param tos The handlers of combo.
     * @param configs The configurations of executing cubes.
     * @param datas The combo datas.
     */
    function _execs(
        address[] memory tos,
        bytes32[] memory configs,
        bytes[] memory datas
    ) internal {
        bytes32[256] memory localStack;
        uint256 index = 0;

        require(
            tos.length == datas.length,
            "Tos and datas length inconsistent"
        );
        require(
            tos.length == configs.length,
            "Tos and configs length inconsistent"
        );
        for (uint256 i = 0; i < tos.length; i++) {
            // Check if the data contains dynamic parameter
            if (!configs[i].isStatic()) {
                // If so, trim the exectution data base on the configuration and stack content
                _trim(datas[i], configs[i], localStack, index);
            }
            // Check if the output will be referenced afterwards
            if (configs[i].isReferenced()) {
                // If so, parse the output and place it into local stack
                uint256 num = configs[i].getReturnNum();
                uint256 newIndex =
                    _parse(localStack, _exec(tos[i], datas[i]), index);
                require(
                    newIndex == index + num,
                    "Return num and parsed return num not matched"
                );
                index = newIndex;
            } else {
                _exec(tos[i], datas[i]);
            }
            // Setup the process to be triggered in the post-process phase
            _setPostProcess(tos[i]);
        }
    }

    /**
     * @notice Trimming the execution data.
     * @param data The execution data.
     * @param config The configuration.
     * @param localStack The stack the be referenced.
     * @param index Current element count of localStack.
     */
    function _trim(
        bytes memory data,
        bytes32 config,
        bytes32[256] memory localStack,
        uint256 index
    ) internal pure {
        // Fetch the parameter configuration from config
        (uint256[] memory refs, uint256[] memory params) = config.getParams();
        // Trim the data with the reference and parameters
        for (uint256 i = 0; i < refs.length; i++) {
            require(refs[i] < index, "Reference to out of localStack");
            bytes32 ref = localStack[refs[i]];
            uint256 offset = params[i];
            uint256 base = PERCENTAGE_BASE;
            assembly {
                let loc := add(add(data, 0x20), offset)
                let m := mload(loc)
                // Adjust the value by multiplier if a dynamic parameter is not zero
                if iszero(iszero(m)) {
                    // Assert no overflow first
                    let p := mul(m, ref)
                    if iszero(eq(div(p, m), ref)) {
                        revert(0, 0)
                    } // require(p / m == ref)
                    ref := div(p, base)
                }
                mstore(loc, ref)
            }
        }
    }

    /**
     * @notice Parse the return data to the local stack.
     * @param localStack The local stack to place the return values.
     * @param ret The return data.
     * @param index The current tail.
     */
    function _parse(
        bytes32[256] memory localStack,
        bytes memory ret,
        uint256 index
    ) internal pure returns (uint256 newIndex) {
        uint256 len = ret.length;
        // Estimate the tail after the process.
        newIndex = index + len / 32;
        require(newIndex <= 256, "stack overflow");
        assembly {
            let offset := shl(5, index)
            // Store the data into localStack
            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 0x20)
            } {
                mstore(
                    add(localStack, add(i, offset)),
                    mload(add(add(ret, i), 0x20))
                )
            }
        }
    }

    /**
     * @notice The execution of a single cube.
     * @param _to The handler of cube.
     * @param _data The cube execution data.
     */
    function _exec(address _to, bytes memory _data)
        internal
        returns (bytes memory result)
    {
        require(_isValid(_to), "Invalid handler");
        _addCubeCounter();
        assembly {
            let succeeded := delegatecall(
                sub(gas(), 5000),
                _to,
                add(_data, 0x20),
                mload(_data),
                0,
                0
            )
            let size := returndatasize()

            result := mload(0x40)
            mstore(
                0x40,
                add(result, and(add(add(size, 0x20), 0x1f), not(0x1f)))
            )
            mstore(result, size)
            returndatacopy(add(result, 0x20), 0, size)

            switch iszero(succeeded)
                case 1 {
                    revert(add(result, 0x20), size)
                }
        }
    }

    /**
     * @notice Setup the post-process.
     * @param _to The handler of post-process.
     */
    function _setPostProcess(address _to) internal {
        // If the stack length equals 0, just skip
        // If the top is a custom post-process, replace it with the handler
        // address.
        if (stack.length == 0) {
            return;
        } else if (
            stack.peek() == bytes32(bytes12(uint96(HandlerType.Custom)))
        ) {
            stack.pop();
            // Check if the handler is already set.
            if (bytes4(stack.peek()) != 0x00000000) stack.setAddress(_to);
            stack.setHandlerType(uint256(HandlerType.Custom));
        }
    }

    /// @notice The pre-process phase.
    function _preProcess() internal virtual isStackEmpty isCubeCounterZero {
        // Set the sender.
        _setSender();
    }

    /// @notice The post-process phase.
    function _postProcess() internal {
        // If the top of stack is HandlerType.Custom (which makes it being zero
        // address when `stack.getAddress()`), get the handler address and execute
        // the handler with it and the post-process function selector.
        // If not, use it as token address and send the token back to user.
        while (stack.length > 0) {
            address addr = stack.getAddress();
            if (addr == address(0)) {
                addr = stack.getAddress();
                _exec(addr, abi.encodeWithSelector(POSTPROCESS_SIG));
            } else {
                uint256 amount = IERC20(addr).balanceOf(address(this));
                if (amount > 0) IERC20(addr).safeTransfer(msg.sender, amount);
            }
        }

        // Balance should also be returned to user
        uint256 amount = address(this).balance;
        if (amount > 0) msg.sender.transfer(amount);

        // Reset the msg.sender and cube counter
        _resetSender();
        _resetCubeCounter();
    }

    /// @notice Get the registry contract address.
    function _getRegistry() internal view returns (address registry) {
        bytes32 slot = HANDLER_REGISTRY;
        assembly {
            registry := sload(slot)
        }
    }

    /// @notice Check if the handler is valid in registry.
    function _isValid(address handler) internal view returns (bool result) {
        return IRegistry(_getRegistry()).isValid(handler);
    }
}
