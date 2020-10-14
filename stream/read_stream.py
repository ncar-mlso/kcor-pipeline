"""Module to handle KCor stream image files and to construct average files with
the standard processing (applying LUTs, averaging, etc) as well as more novel
algorithms to remove aerosols.
"""

import configparser
import glob
import os
import warnings

import astropy.io.fits
from astropy.utils.exceptions import AstropyUserWarning
import numpy as np
import matplotlib.pyplot as plt


# camera information
N_CAMERAS = 2
N_STATES = 4
HEIGHT = 1024
WIDTH = 1024
N_ADC = 4

# stream file information
N_IMAGES_PER_FILE = 2


def read_raw_stream(raw_filename):
    """Read a raw stream data file. Returns an array of unsigned 16-bit integers
    of size `N_IMAGES_PER_FILE, N_STATES, HEIGHT, WIDTH`.
    """
    with open(raw_filename) as raw_file:
        im = np.fromfile(raw_file, dtype=np.uint16)
        im = im.reshape(N_IMAGES_PER_FILE, N_STATES, HEIGHT, WIDTH)

    return(im)


def read_lut(lut_filename):
    """Read a single `.bin` LUT file, returning a 4096 element 32-bit unsigned
    integer array.
    """
    with open(lut_filename) as lut_file:
        lut = np.fromfile(lut_file, dtype=np.uint32)

    return(lut)


def read_luts(lut_root, camera_id, lut_id):
    """Read the `N_ADC` files associated with a given `camera_id` and `lut_id`,
    i.e., "20200615". Returns a list of length `N_ADC`.
    """
    luts = [read_lut(os.path.join(lut_root,
        f"Photonfocus_MV-D1024E_{camera_id}_adc{adc}_{lut_id}.bin"))
            for adc in range(N_ADC)]
    return(luts)


def apply_lut(im, lut):
    """Expands a raw unsigned 16-bit integer stream image of size
    `N_IMAGES, N_STATES, HEIGHT, WIDTH` to an unsigned 32-bit integer array of
    the same shape using the given LUTs.
    """
    new_im = np.empty_like(im, dtype=np.uint32)
    for i in range(im.shape[0]):
        for s in range(N_STATES):
            for adc in range(N_ADC):
                adc_lut = lut[adc]
                new_im[i, s, :, adc::N_ADC] = adc_lut[im[i, s, :, adc::N_ADC]]

    return(new_im)


def display_image(im, dpi=80, minimum=-20.0, maximum=200.0):
    """Display an image with no axes at full resolution.
    """
    height, width = im.shape
    figsize = width / float(dpi), height / float(dpi)

    fig = plt.figure(figsize=figsize)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.axis("off")
    ax.imshow(im, cmap="Greys_r", origin="lower", vmin=minimum, vmax=maximum)
    plt.show()


def read_time(root, datetime, luts):
    """Read all the files corresponding to a date/time in a given directory, and
    place into an array with shape `(numsum, n_cameras, n_states, height, width)`.
    """
    # find files in root that begin with datetime by camera
    all_files = [glob.glob(os.path.join(root, f"{datetime}_kcor_cam{cam}_????.raw")) for cam in [0, 1]]
    numsum = len(all_files[0]) * N_IMAGES_PER_FILE
    # TODO: should check that len(all_files[i]) is the same for all i

    shape = (numsum, N_CAMERAS, N_STATES, HEIGHT, WIDTH)
    frames = np.empty(shape, dtype=np.uint32)

    for c, cam_files in enumerate(all_files):
        for i, f in enumerate(cam_files):
            basename = os.path.basename(f)
            frames[i * N_IMAGES_PER_FILE:(i + 1) * N_IMAGES_PER_FILE, c, :, :, :] \
              = apply_lut(read_raw_stream(f), luts[c])

    return(frames, numsum)


def corona(im):
    """Calculate the corona from a `(n_states, height, width)` shaped float array.
    """
    return(np.sqrt((im[0, :, :] - im[3, :, :])**2 + (im[1, :, :] - im[2, :, :])**2))


def naive_sum(frames):
    """Naively sum the frames (no aerosol removal). `frames` is a `uint16` array
    of shape `numsum, N_CAMERAS, N_STATES, HEIGHT, WIDTH`.
    """
    return(np.sum(frames.astype(np.float32), axis=0))


def median_image(frames):
    """Get the median image."""
    return(np.median(frames, axis=0).astype(frames.dtype))


def remove_aerosol(frames):
    """Remove aerosols from frames. `frames` is a `uint16` array of shape
    `numsum, N_CAMERAS, N_STATES, HEIGHT, WIDTH`.
    """

    frames_mean = np.median(frames, axis=0).astype(frames.dtype)
    frames_median = np.median(frames, axis=0).astype(frames.dtype)

    numsum = frames.shape[0]
    ss = 4.0 / 44.0 * np.sqrt(44.0)
    threshold = numsum * 0.90

    corrected = np.empty((N_CAMERAS, N_STATES, HEIGHT, WIDTH), dtype=frames.dtype)

    for c in range(N_CAMERAS):
        for s in range(N_STATES):
            for h in range(HEIGHT):
                for w in range(WIDTH):
                    ind = np.where(np.abs(frames[:, c, s, h, w] - frames_median[c, s, h, w]) < ss * np.sqrt(frames_median[c, s, h, w]))
                    if ind[0].size > threshold:
                        corrected[c, s, h, w] = np.mean(frames[ind, c, s, h, w])
                    else:
                        corrected[c, s, h, w] = frames_mean[c, s, h, w]
    return(corrected)


def quicklook(stream_root, datetime, n_cameras=2):
    """Calculate simple averaged quicklook image from a file location and
    date/time.
    """
    frames, numsum = read_time(stream_root, datetime)
    #average_image = naive_sum(frames)
    average_image = remove_aerosol(frames)
    return([corona(average_image[cam, :, :, :])
              for cam in np.arange(n_cameras, dtype=np.int16)])

def main():
    date = "20200911"
    script_location = os.path.dirname(os.path.abspath(__file__))

    # read options from config file
    stream_config_filename = os.path.join(script_location, "stream.cfg")
    options = configparser.ConfigParser()
    options.read(stream_config_filename)

    output_root = os.path.join(options.get("results", "root"), date)
    stream_root = os.path.join(options.get("stream_data", "root"), date)
    raw_root = os.path.join(options.get("raw_data", "root"), date, "level0")
    lut_root = os.path.join(options.get("LUTs", "root"))
    lut_identifier = os.path.join(options.get("LUTs", "identifier"))

    print(f"output root : {output_root}")
    print(f"stream root : {stream_root}")
    print(f"raw root : {raw_root}")
    print(f"LUT root : {lut_root}")
    print(f"LUT identifier : {lut_identifier}")

    all_raw_files = glob.glob(os.path.join(raw_root, "*_kcor.fts.gz"))
    all_raw_files = sorted(all_raw_files)

    #datetimes = ["20200908_172438"]
    #datetimes = ["20200908_172453"]
    #datetimes = ["20200908_172438", "20200908_172453"]
    #datetimes = ["20200911_213854"]
    datetimes =  [os.path.basename(f)[0:15] for f in all_raw_files]
    for dt in datetimes:
        metadata_filename = glob.glob(os.path.join(raw_root, f"{dt}*.fts.gz"))[0]
        output_basename = os.path.basename(metadata_filename)
        output_filename = os.path.join(os.path.join(output_root, output_basename))

        if os.path.exists(output_filename):
            print(f"Skipping {dt}...")
            continue

        metadata_hdulist = astropy.io.fits.open(metadata_filename)
        tcam_id = metadata_hdulist[0].header["TCAMID"]
        rcam_id = metadata_hdulist[0].header["RCAMID"]
        luts = {0: read_luts(lut_root, rcam_id, lut_identifier),
                1: read_luts(lut_root, tcam_id, lut_identifier)}
        
        print(f"Reading {dt}...")
        frames, numsum = read_time(stream_root, dt, luts)
        print(frames.shape)

        if numsum > 0:
            print(f"  min={np.min(frames)} max={np.max(frames)}")
            print(f"Summing {dt}...")
            average_image = (naive_sum(frames) / 2**16).astype(np.uint16)
            #average_image = remove_aerosol(frames).astype(np.uint16)
            #average_image = 2**4 * median_image(frames).astype(np.uint16)
            print(f"  min={np.min(average_image)} max={np.max(average_image)}")

            metadata_hdulist[0].data = average_image

        print(f"Writing {dt}...")
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", AstropyUserWarning)
            metadata_hdulist.writeto(output_filename, output_verify="ignore") 

if __name__ == "__main__":
    main()
