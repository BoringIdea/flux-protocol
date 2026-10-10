// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC6551Account } from "../interfaces/IERC6551.sol";

contract FluxAccount is IERC6551Account {
    using SafeERC20 for IERC20;

    address public immutable nft;
    uint256 public immutable tokenId;
    address public immutable manager;
    uint256 public immutable chainId;
    address public immutable implementation;
    uint256 public state;

    error NotOwner();
    error NotManager();
    error ExecutionFailed();

    event Executed(address indexed target, uint256 value, bytes data);
    event ProtocolSweep(address indexed asset, address indexed recipient, uint256 amount);

    constructor(address nft_, uint256 tokenId_, address manager_, uint256 chainId_, address implementation_) {
        nft = nft_;
        tokenId = tokenId_;
        manager = manager_;
        chainId = chainId_;
        implementation = implementation_;
    }

    receive() external payable { }

    function token() external view returns (uint256 chainId_, address tokenContract, uint256 tokenId_) {
        return (chainId, nft, tokenId);
    }

    function owner() public view returns (address) {
        try IERC721(nft).ownerOf(tokenId) returns (address holder) {
            return holder;
        } catch {
            return address(0);
        }
    }

    function execute(address target, uint256 value, bytes calldata data)
        external
        payable
        returns (bytes memory result)
    {
        if (msg.sender != owner()) revert NotOwner();
        ++state;
        (bool ok, bytes memory returned) = target.call{ value: value }(data);
        if (!ok) revert ExecutionFailed();
        emit Executed(target, value, data);
        return returned;
    }

    function protocolSweep(address asset, address recipient) external returns (uint256 amount) {
        if (msg.sender != manager) revert NotManager();
        if (asset == address(0)) {
            amount = address(this).balance;
            if (amount != 0) {
                (bool ok,) = recipient.call{ value: amount }("");
                if (!ok) revert ExecutionFailed();
            }
        } else {
            amount = IERC20(asset).balanceOf(address(this));
            if (amount != 0) IERC20(asset).safeTransfer(recipient, amount);
        }
        emit ProtocolSweep(asset, recipient, amount);
    }
}
