# SPOTeval v1.6.2

SPOTeval (Proton Spot Profile Evaluation) is MATLAB software for analysis of **one isolated proton pencil-beam spot per image** from radiochromic-film or scintillator-camera optical-dosimeter measurements. It performs lateral spot-profile analysis; it is **not** a complete proton treatment-planning-system beam-model commissioning package and does not process integral depth-dose/reference-dosimetry data.

## Release

- Version: **1.6.2**
- Main file: `Spot_Profile_Analyzer_v1_6_2.m`
- License: MIT
- Repository: https://github.com/physcein/SPOTeval-proton-spot-analysis
- Archived release: https://doi.org/10.5281/zenodo.21348140

## MATLAB requirements

SPOTeval was originally developed in MATLAB R2012b. The code uses functionality from MATLAB plus the Image Processing Toolbox (including image display, resizing, rotation, and ROI functions) and Curve Fitting Toolbox (`fit`, `fittype`, and `prepareCurveData`). Because the GUI is a legacy MATLAB implementation, users should validate operation in their local MATLAB release before commissioning use.

## Supported input pathways

1. **Radiochromic film** (`.tif` and compatible image inputs after local film scanning/calibration).
2. **Optical dosimeter system (ODS)** images, including `.CR2` images from the custom scintillator-camera system described by Hsi et al. (AAPM 2014).

The current ODS implementation sums the RGB channels and assumes a linear scintillator-signal-to-relative-dose relationship. Detector response and spatial calibration must be verified locally before use.

## Measurement geometry and pixel scaling

The historical ODS geometric calibration was obtained by measuring the number of image pixels corresponding to known physical distances independently in X and Y. The default GUI displays approximately **0.0086 cm/pixel in X** and **0.0084 cm/pixel in Y**. Axis-specific calibration is retained because the camera system exhibited slightly different spatial scaling in the two directions.

## Filename convention

The legacy workflow encodes measurement metadata in the filename. Examples:

- `E070ZD200NET175.CR2` -> 70 MeV, z = -200 mm, NET = 1.75 mm
- `E150ZI000NET175.CR2` -> 150 MeV, z = 0 mm, NET = 1.75 mm
- `E250ZU200NET175.CR2` -> 250 MeV, z = +200 mm, NET = 1.75 mm

`D`, `I`, and `U` encode negative, zero/isocenter, and positive z positions, respectively. `NET175` is interpreted as 1.75 mm.

**Safety note:** filename metadata are user-supplied. Version 1.6.2 checks that the required E/Z/NET fields are structurally present and that parsed values are finite scalars, but it cannot determine whether a syntactically valid filename contains clinically incorrect metadata. For clinical implementation, a separately controlled metadata manifest (for example CSV/JSON), provenance logging, and independent review are recommended.

## Typical workflow

1. Start MATLAB and place `Spot_Profile_Analyzer_v1_6_2.m` on the MATLAB path.
2. Run `Spot_Profile_Analyzer_v1_6_2`.
3. Select the measurement type (Film or Optical Dosimeter System).
4. Select single- or double-Gaussian fitting.
5. Set a background image when appropriate.
6. Verify pixel scaling and the displayed metadata.
7. Select a measurement image and run **Evaluate!**.
8. Review the ROI, 2D contour, X/Y profiles, and quantitative metrics.
9. Use **Analyze Rotational Symmetry** when a descriptive 2D orientation/shape assessment is desired.
10. Enable W2CAD output only when an Eclipse-compatible lateral-profile export is required.

## Outputs

SPOTeval can produce:

- append-style CSV summary of analyzed conditions;
- X- and Y-direction profile text files;
- cropped ROI JPEG images;
- Eclipse-specific W2CAD-style ASCII lateral-profile files when enabled.

Reported metrics include FWHM, FWHM-derived sigma, Gaussian-fit sigma, FW10%M, 80%-20% penumbra, profile symmetry, image-coordinate center, fit type, and fit weights.

The reported center is the detected center within the measurement image. SPOTeval v1.6.2 is **not validated as an independent delivered-spot-position QA system** relative to requested scanning coordinates.

## Rotational symmetry module

The module samples the measured 50% contour, estimates an orientation from valid contour points, and displays the original and rotated distributions for descriptive assessment of rotational asymmetry. Version 1.6.2 adds scalar-safe handling of tied/empty contour candidates before image rotation. The module does not apply a clinical pass/fail threshold; local acceptance criteria would require separate validation.

## Demonstration and validation data

The manuscript demonstration dataset comprises 76 energies from 70 to 250 MeV measured at z = -200, 0, and +200 mm (228 conditions) with the ODS.

Independent validation uses archived EBT3 radiochromic-film reference profiles matched to the same 228 energy-position conditions. A compact labeled example dataset is provided separately for repository demonstration. The full historical dataset can be made available upon reasonable request.

## Validation summary

For 228 matched ODS/SPOTeval conditions and EBT3-film reference profiles:

| Metric | Bias (SPOTeval - film), mm | MAE, mm | RMSE, mm | Maximum absolute difference, mm | Pearson r |
|---|---:|---:|---:|---:|---:|
| FWHM X | +0.259 | 0.259 | 0.266 | 0.426 | 0.999998 |
| FWHM Y | -0.304 | 0.304 | 0.308 | 0.453 | 0.999998 |
| Gaussian-fit sigma X | +0.029 | 0.030 | 0.034 | 0.090 | 0.999816 |
| Gaussian-fit sigma Y | +0.061 | 0.061 | 0.064 | 0.126 | 0.999668 |

All 456 directional FWHM comparisons were within 0.5 mm of the matched EBT3-film reference profiles.

## Scope and limitations

SPOTeval v1.6.2 should be regarded as an **open-source research/commissioning prototype**. Its principal scope is lateral single-spot profile analysis. The W2CAD export is Eclipse-specific and does not constitute a complete beam model. Depth-dose data, absolute/reference dosimetry, range-shifter characterization, and final TPS beam-model commissioning/validation require separate measurements and procedures. The legacy filename parser and detector-specific calibration assumptions require local verification and controlled workflow governance before clinical deployment.

## Citation

When using SPOTeval, cite the archived release and the associated Medical Physics software article once published. Repository citation metadata are provided in `CITATION.cff`.
