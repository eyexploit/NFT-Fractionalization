// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./ERC721TokenVault.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract ERC721VaultFactory is Ownable, Pausable {
    uint256 public vaultCount;
    mapping(uint256 => address) public vaults;

    // @notice the tokenvault logic contract
    address public immutable logic;

    event CreateVault();

    constructor() {
        logic = address(new TokenVault());
    }

    function createVault(
        address _curator,
        string memory name,
        string memory symbol,
        uint256 _supply,
        address _token,
        uint256 id
    ) external whenNotPaused {
        TokenVault vault = new TokenVault();
        IERC721(_token).transferFrom(msg.sender, address(vault), id);
        vault.initialize(_curator, name, symbol, _supply, _token, id);

        emit CreateVault();
        vaults[vaultCount] = address(vault);
        vaultCount++;
    }
}
