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

from raysect.optical.material.emitter cimport InhomogeneousVolumeEmitter

from cherab.core.plasma cimport Plasma
from cherab.core.beam cimport Beam
from cherab.core.atomic cimport AtomicData


cdef class BeamMaterial(InhomogeneousVolumeEmitter):

    cdef:
        Beam _beam
        Plasma _plasma
        AtomicData _atomic_data
        list _models
