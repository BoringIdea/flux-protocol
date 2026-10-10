// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { TraitStorage } from "./TraitStorage.sol";
import { FrogBodyRenderer } from "./FrogBodyRenderer.sol";
import { FrogFaceRenderer } from "./FrogFaceRenderer.sol";
import { FrogHeadRenderer } from "./FrogHeadRenderer.sol";

/// @notice Fully on-chain 48x48 Flux Frog SVG and metadata composer.
contract TraitRenderer {
    using Strings for uint256;

    TraitStorage public immutable traitStorage;
    FrogBodyRenderer public immutable bodyRenderer;
    FrogFaceRenderer public immutable faceRenderer;
    FrogHeadRenderer public immutable headRenderer;

    constructor(
        TraitStorage storage_,
        FrogBodyRenderer bodyRenderer_,
        FrogFaceRenderer faceRenderer_,
        FrogHeadRenderer headRenderer_
    ) {
        traitStorage = storage_;
        bodyRenderer = bodyRenderer_;
        faceRenderer = faceRenderer_;
        headRenderer = headRenderer_;
    }

    function tokenURI(uint256 assetId, bool genesis) external view returns (string memory) {
        TraitStorage.TraitData memory t = traitStorage.traits(assetId);
        string memory json = string.concat(
            '{"name":"',
            genesis ? "Genesis Flux Frog" : "Flux Frog",
            " #",
            assetId.toString(),
            '","description":"A fully on-chain dynamic 48x48 pixel frog from Flux Protocol.",',
            '"attributes":',
            _attributes(t, genesis),
            ',"image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(_renderSVG(t, genesis))),
            '"}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    function renderSVG(uint256 assetId, bool genesis) external view returns (string memory) {
        return _renderSVG(traitStorage.traits(assetId), genesis);
    }

    function _renderSVG(TraitStorage.TraitData memory t, bool genesis)
        internal
        view
        returns (string memory)
    {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" ',
            'shape-rendering="crispEdges" role="img" aria-label="Flux Frog">',
            bodyRenderer.renderBackground(t.background, t.backgroundStyle),
            bodyRenderer.renderBody(t.body, t.skin),
            headRenderer.renderHead(t.body, t.head),
            faceRenderer.renderEyes(t.body, t.eyes),
            faceRenderer.renderMouth(t.body, t.mouth),
            headRenderer.renderAccessory(t.body, t.accessory),
            genesis ? headRenderer.genesisMark() : "",
            "</svg>"
        );
    }

    function _attributes(TraitStorage.TraitData memory t, bool genesis)
        internal
        pure
        returns (string memory)
    {
        return string.concat(
            '[{"trait_type":"Background","value":"',
            _backgroundName(t.background),
            '"},{"trait_type":"Background Scene","value":"',
            _sceneName(t.backgroundStyle),
            '"},{"trait_type":"Body","value":"',
            _bodyName(t.body),
            '"},{"trait_type":"Skin","value":"',
            _skinName(t.skin),
            '"},{"trait_type":"Eyes","value":"',
            _eyesName(t.eyes),
            '"},{"trait_type":"Mouth","value":"',
            _mouthName(t.mouth),
            '"},{"trait_type":"Head","value":"',
            _headName(t.head),
            '"},{"trait_type":"Accessory","value":"',
            _accessoryName(t.accessory),
            '"},{"trait_type":"Genesis","value":"',
            genesis ? "Yes" : "No",
            '"}]'
        );
    }

    function _backgroundName(uint16 v) internal pure returns (string memory) {
        string[12] memory n = [
            "Sage Pond",
            "Periwinkle",
            "Peach",
            "Lagoon",
            "Warm Sand",
            "Lavender",
            "Sunrise",
            "Sky Blue",
            "Dusk",
            "Marsh Green",
            "Candy Pink",
            "Ice"
        ];
        return n[v % 12];
    }

    function _sceneName(uint16 v) internal pure returns (string memory) {
        string[14] memory n = [
            "Solid",
            "Pond Ripples",
            "Pixel Clouds",
            "Fireflies",
            "Reeds",
            "Bubbles",
            "Sunny Day",
            "Star Field",
            "Crescent Moon",
            "Grassland",
            "Forest",
            "Lotus Pond",
            "Rainbow",
            "Rain Shower"
        ];
        return n[v % 14];
    }

    function _bodyName(uint16 v) internal pure returns (string memory) {
        string[12] memory n = [
            "Flux Lime",
            "Mint",
            "Aqua",
            "Golden",
            "Amethyst",
            "Coral",
            "Snow",
            "Midnight",
            "Sakura",
            "Royal Blue",
            "Venom",
            "Cocoa"
        ];
        return n[v % 12];
    }

    function _skinName(uint16 v) internal pure returns (string memory) {
        string[6] memory n =
            ["Clean", "Freckles", "Poison Spots", "Moss Patches", "Tiger Stripes", "Cyber Panels"];
        return n[v % 6];
    }

    function _eyesName(uint16 v) internal pure returns (string memory) {
        string[16] memory n = [
            "Round",
            "Sleepy",
            "Star",
            "Goggles",
            "Angry",
            "Happy",
            "Hypnotic",
            "Laser Visor",
            "Sunglasses",
            "Monocle",
            "3D Glasses",
            "Heart Glasses",
            "Nerd Glasses",
            "Eye Patch",
            "Aviators",
            "Pixel Shades"
        ];
        return n[v % 16];
    }

    function _mouthName(uint16 v) internal pure returns (string memory) {
        string[16] memory n = [
            "Soft Smile",
            "Flat",
            "Big Grin",
            "Tongue Out",
            "Tiny Fangs",
            "Ooh",
            "Smirk",
            "Bubblegum",
            "Gold Tooth",
            "Cigarette",
            "Cigar",
            "Pipe",
            "Mustache",
            "Lollipop",
            "Pacifier",
            "Rose Stem"
        ];
        return n[v % 16];
    }

    function _headName(uint16 v) internal pure returns (string memory) {
        string[18] memory n = [
            "Bare",
            "Party Hat",
            "Crown",
            "Sprout",
            "Wizard Hat",
            "Mushroom Cap",
            "Halo",
            "Viking Horns",
            "Beanie",
            "Lotus",
            "Baseball Cap",
            "Top Hat",
            "Cowboy Hat",
            "Bucket Hat",
            "Mohawk",
            "Afro",
            "Side Part",
            "Long Hair"
        ];
        return n[v % 18];
    }

    function _accessoryName(uint16 v) internal pure returns (string memory) {
        string[6] memory n = ["None", "Sparkle", "Bow Tie", "Blush", "Fly Friend", "Gold Chain"];
        return n[v % 6];
    }
}
