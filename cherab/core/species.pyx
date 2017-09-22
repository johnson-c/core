# cython: language_level=3

# Copyright 2014-2017 United Kingdom Atomic Energy Authority
#
# Licensed under the EUPL, Version 1.1 or – as soon they will be approved by the
# European Commission - subsequent versions of the EUPL (the "Licence");
# You may not use this work except in compliance with the Licence.
# You may obtain a copy of the Licence at:
#
# https://joinup.ec.europa.eu/software/page/eupl5
#
# Unless required by applicable law or agreed to in writing, software distributed
# under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.
#
# See the Licence for the specific language governing permissions and limitations
# under the Licence.

from cherab.core.atomic cimport Element
from cherab.core.distribution cimport DistributionFunction


# immutable, so the plasma doesn't have to track changes
cdef class Species:
    """
    Plasma species.

    :param element: An element object.
    :param ionisation: The ionisation state of the species.
    :param distribution: A distribution function for the species.
    """

    def __init__(self, Element element, int ionisation, DistributionFunction distribution):

        if ionisation > element.atomic_number:
            raise ValueError("Ionisation level cannot be larger than the atomic number.")

        if ionisation < 0:
            raise ValueError("Ionisation level cannot be less than zero.")

        self.element = element
        self.ionisation = ionisation
        self.distribution = distribution

    def __repr__(self):
        return '<Species: element={}, ionisation={}>'.format(self.element.name, self.ionisation)


# todo: move to a common exception module
class SpeciesNotFound(Exception):
    pass
