// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.17;

import "./wrapERC20.sol";
import "./ownable.sol";
import "./multiSign.sol";

contract BridgeWrap is WrapERC20, Ownable, MultiSign {
    uint24 public constant FEE_DIV_CONST = 100000;
    uint24 public constant feeRate = 1000; // it means %1 (feeRate / FEE_DIV_CONST * 100%)
    uint256 public feeSum;

    struct WrapTx {
        uint256 amount;
        address payable to;
        uint8 requiredCount;
        bool sent;
    }
    mapping(bytes32 => WrapTx) wraps; // txid => WrapTx
    mapping(address => mapping(bytes32 => bool)) isWrapped; // signer => txid => isWrapped

    event Wrap(address indexed to, uint256 amount);
    event UnWrap(
        address indexed from,
        bytes32 indexed to,
        bytes32 symbol,
        uint256 amount
    );

    constructor(
        string memory _symbol,
        uint8 _decimal,
        address[] memory _signers,
        uint8 _requireCount
    ) WrapERC20(_symbol, _decimal) MultiSign(_signers, _requireCount) {
        owner = msg.sender;
    }

    // mint ERC20 token to user
    // this is multSign
    function wrap(
        bytes32 txid,
        uint256 amount,
        address payable to
    ) external onlySigner {
        require(!wraps[txid].sent, "wrapped finished");
        require(!isWrapped[msg.sender][txid], "sender wrapped");
        if (wraps[txid].to == address(0)) {
            wraps[txid] = WrapTx(amount, to, 0, false);
        } else {
            require(
                wraps[txid].amount == amount && wraps[txid].to == to,
                "invalid wrap"
            );
        }

        if (!isWrapped[msg.sender][txid]) {
            isWrapped[msg.sender][txid] = true;
            wraps[txid].requiredCount++;
        }

        if (wraps[txid].requiredCount >= requireCount) {
            wraps[txid].sent = true;
            uint256 fee = (amount * feeRate) / FEE_DIV_CONST;
            feeSum += fee;
            amount -= fee;
            _mint(to, amount);
            emit Wrap(to, amount);
        }
    }

    function unWrap(
        bytes32 to,
        bytes32 symbol,
        uint256 amount
    ) public {
        _burn(msg.sender, amount);
        uint256 fee = (amount * feeRate) / FEE_DIV_CONST;
        feeSum += fee;
        emit UnWrap(msg.sender, to, symbol, amount - fee);
    }

    //withdraw the fee to dev team
    function withdrawFee(address to, uint256 fee) external {
        require(msg.sender == owner, "forbidden");
        feeSum -= fee;
        _mint(to, fee);
    }

    //unwrap the fee to dev team
    function unWrapFee(
        bytes32 to,
        bytes32 symbol,
        uint256 fee
    ) external {
        require(msg.sender == owner, "forbidden");
        feeSum -= fee;
        emit UnWrap(owner, to, symbol, fee);
    }
}
