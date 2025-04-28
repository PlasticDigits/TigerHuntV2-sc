// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEntityNFT} from "../../src/interfaces/IEntityNFT.sol";

contract MockEntityNFT is IEntityNFT, ERC721Enumerable, Ownable {
    constructor() ERC721("MockEntity", "MOCK") Ownable(msg.sender) {}

    function getEntityId() external pure returns (uint256) {
        return 1;
    }

    function mint(address to, uint256 tokenId) external override {
        _mint(to, tokenId);
    }

    function owner() public view override(Ownable) returns (address) {
        return super.owner();
    }

    // Override ownerOf to handle the token ID conversion
    function ownerOf(
        uint256 tokenId
    ) public view virtual override(ERC721, IERC721) returns (address) {
        return super.ownerOf(tokenId);
    }
}
